#!/usr/bin/env bash
set -Eeuo pipefail

readonly DEFAULT_OPERATION_TIMEOUT_SECONDS=600
readonly DEFAULT_DRAIN_TIMEOUT_SECONDS=21600
readonly DEFAULT_STABILITY_SECONDS=60
readonly DEFAULT_QUIESCENCE_SECONDS=60
readonly DEFAULT_POLL_SECONDS=5
readonly WAIT_PROGRESS_SECONDS=60

OPERATION_TIMEOUT_SECONDS="${ARC_MIGRATION_TIMEOUT_SECONDS:-$DEFAULT_OPERATION_TIMEOUT_SECONDS}"
DRAIN_TIMEOUT_SECONDS="${ARC_MIGRATION_DRAIN_TIMEOUT_SECONDS:-$DEFAULT_DRAIN_TIMEOUT_SECONDS}"
STABILITY_SECONDS="${ARC_MIGRATION_STABILITY_SECONDS:-$DEFAULT_STABILITY_SECONDS}"
QUIESCENCE_SECONDS="${ARC_MIGRATION_QUIESCENCE_SECONDS:-$DEFAULT_QUIESCENCE_SECONDS}"
POLL_SECONDS="${ARC_MIGRATION_POLL_SECONDS:-$DEFAULT_POLL_SECONDS}"
PHASE="argument parsing"
TF_DIR=""
FROM=""
TO=""
EXPECTED_ACCOUNT_ID=""
NON_INTERACTIVE=false
LIVE_MODE=""
RUNNER_COUNT=0
EXPECTED_RUNNER_NAMES_JSON='[]'

log_message() {
    local level=$1
    shift
    printf '%-9s %s\n' "[$level]" "$*"
}

log_phase() {
    printf '\n'
    log_message PHASE "$*"
}

log_check() {
    log_message CHECK "$*"
}

log_wait() {
    log_message WAIT "$*"
}

log_ok() {
    log_message OK "$*"
}

log_info() {
    log_message INFO "$*"
}

log_warn() {
    log_message WARN "$*"
}

log_apply() {
    log_message APPLY "$*"
}

usage() {
    printf '%s\n' \
        "Usage: migrate-tenant.sh --tf-dir DIR --from-cluster NAME --to-cluster NAME \\" \
        '  --expected-account-id ID [--non-interactive]' \
        '' \
        "The script drains and removes a tenant's ARC resources from the source cluster," \
        'proves the live source and destination are clean, enables ARC on the destination,' \
        'and checks the destination for a healthy, conflict-free deployment.'
}

die() {
    echo "ERROR [$PHASE]: $*" >&2
    exit 1
}

on_error() {
    local exit_code=$?
    echo "ERROR: ARC migration stopped during phase '$PHASE' (exit $exit_code)." >&2
    echo "Source: ${FROM:-unknown}; destination: ${TO:-unknown}; tenant: ${TENANT:-unknown}" >&2
    echo 'The workflow must not continue to cluster destruction or workflow re-enablement.' >&2
    exit "$exit_code"
}

trap on_error ERR

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command is unavailable: $1"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --tf-dir)
            [[ $# -ge 2 ]] || die '--tf-dir requires a value'
            TF_DIR=$2
            shift 2
            ;;
        --from-cluster)
            [[ $# -ge 2 ]] || die '--from-cluster requires a value'
            FROM=$2
            shift 2
            ;;
        --to-cluster)
            [[ $# -ge 2 ]] || die '--to-cluster requires a value'
            TO=$2
            shift 2
            ;;
        --expected-account-id)
            [[ $# -ge 2 ]] || die '--expected-account-id requires a value'
            EXPECTED_ACCOUNT_ID=$2
            shift 2
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *) die "unknown argument: $1" ;;
        esac
    done

    [[ -d "$TF_DIR" ]] || die "tenant directory does not exist: $TF_DIR"
    TF_DIR=$(cd -- "$TF_DIR" && pwd)
    CONFIG_FILE="${TF_DIR}/config.yml"
    [[ -f "$CONFIG_FILE" ]] || die "tenant config does not exist: $CONFIG_FILE"
    [[ -n "$FROM" ]] || die '--from-cluster is required'
    [[ -n "$TO" ]] || die '--to-cluster is required'
    [[ "$FROM" != "$TO" ]] || die 'source and destination clusters must differ'
    [[ "$EXPECTED_ACCOUNT_ID" =~ ^[0-9]{12}$ ]] ||
        die 'expected account ID must contain 12 digits'

    local from_base to_base
    case "$FROM" in
    *-blue) from_base=${FROM%-blue} ;;
    *-green) from_base=${FROM%-green} ;;
    *) die 'source cluster must end in -blue or -green' ;;
    esac
    case "$TO" in
    *-blue) to_base=${TO%-blue} ;;
    *-green) to_base=${TO%-green} ;;
    *) die 'destination cluster must end in -blue or -green' ;;
    esac
    [[ "$from_base" == "$to_base" ]] || die 'source and destination are not a blue/green pair'

    TENANT=$(basename "$TF_DIR")
}

render_inputs() {
    local rendered key expected_count
    rendered=$(terragrunt render --format json --working-dir "$TF_DIR")
    AWS_PROFILE=$(jq -er '.inputs.aws_profile' <<<"$rendered")
    AWS_REGION=$(jq -er '.inputs.aws_region' <<<"$rendered")
    DEPLOYMENT_PREFIX=$(jq -er '.inputs.deployment_config.deployment_prefix' <<<"$rendered")
    RENDERED_TENANT=$(jq -er '.inputs.deployment_config.tenant.name' <<<"$rendered")
    RENDERED_CLUSTER=$(jq -er '.inputs.arc_deployment_specs.cluster_name' <<<"$rendered")
    [[ "$RENDERED_TENANT" == "$TENANT" ]] ||
        die "rendered tenant '$RENDERED_TENANT' does not match directory tenant '$TENANT'"
    jq -e '.inputs.arc_deployment_specs.runner_specs | type == "object"' <<<"$rendered" >/dev/null ||
        die 'rendered ARC runner specifications must be an object'

    RUNNER_NAMES=()
    while IFS= read -r key; do
        RUNNER_NAMES[RUNNER_COUNT]=$(jq -er --arg key "$key" \
            '.inputs.arc_deployment_specs.runner_specs[$key].scale_set_name' <<<"$rendered")
        RUNNER_COUNT=$((RUNNER_COUNT + 1))
    done < <(jq -r '.inputs.arc_deployment_specs.runner_specs | keys[]?' <<<"$rendered")

    expected_count=$RUNNER_COUNT
    if ((RUNNER_COUNT > 0)); then
        EXPECTED_RUNNER_NAMES_JSON=$(jq -cn '$ARGS.positional | sort' --args "${RUNNER_NAMES[@]}")
        [[ "$(jq 'unique | length' <<<"$EXPECTED_RUNNER_NAMES_JSON")" == "$expected_count" ]] ||
            die 'ARC scale-set names must be unique'
    fi

    FROM_CTX="${FROM}-${AWS_PROFILE}-${AWS_REGION}"
    TO_CTX="${TO}-${AWS_PROFILE}-${AWS_REGION}"
}

update_config() {
    local migrate_flag=$1 cluster_name=$2
    log_check "Updating tenant config: cluster=$cluster_name migrate_arc_cluster=$migrate_flag."
    yq e -i ".migrate_arc_cluster = $migrate_flag" "$CONFIG_FILE"
    yq e -i ".arc_cluster_name = \"$cluster_name\"" "$CONFIG_FILE"
    log_ok "Tenant config updated: cluster=$cluster_name migrate_arc_cluster=$migrate_flag."
}

cluster_ready() {
    kubectl --context "$1" get --raw=/readyz 2>/dev/null | grep -qx ok
}

pod_identity_associations() {
    aws eks list-pod-identity-associations \
        --cluster-name "$1" \
        --namespace "$TENANT" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --output json
}

# A StorageClass can legitimately outlive an ARC installation, so it is not an
# ownership signal. Namespace, Karpenter resources, and Pod Identity are.
cluster_is_clean() {
    local context=$1 cluster=$2 object associations

    object=$(kubectl --context "$context" get namespace "$TENANT" --ignore-not-found -o name) || return 2
    [[ -z "$object" ]] || return 1
    object=$(kubectl --context "$context" get nodepool.karpenter.sh "karpenter-${TENANT}" --ignore-not-found -o name) || return 2
    [[ -z "$object" ]] || return 1
    object=$(kubectl --context "$context" get ec2nodeclass.karpenter.k8s.aws "karpenter-${TENANT}" --ignore-not-found -o name) || return 2
    [[ -z "$object" ]] || return 1
    associations=$(pod_identity_associations "$cluster") || return 2
    jq -e '.associations | length == 0' <<<"$associations" >/dev/null || return 1
}

detect_live_mode() {
    local source_status destination_status
    if cluster_is_clean "$FROM_CTX" "$FROM"; then
        source_status=0
    else
        source_status=$?
    fi
    if cluster_is_clean "$TO_CTX" "$TO"; then
        destination_status=0
    else
        destination_status=$?
    fi

    [[ "$source_status" != 2 ]] || die "unable to inspect source cluster '$FROM'"
    [[ "$destination_status" != 2 ]] || die "unable to inspect destination cluster '$TO'"

    case "${source_status}:${destination_status}" in
    1:0)
        LIVE_MODE=move
        log_ok "Tenant ARC footprint exists only on source '$FROM'; a full move is required."
        ;;
    0:0)
        LIVE_MODE=resume-after-source-cleanup
        log_info 'Both clusters are clean; continuing with destination activation.'
        ;;
    0:1)
        LIVE_MODE=resume-destination
        log_info "Source is clean and destination has the tenant; reconciling and validating '$TO'."
        ;;
    1:1)
        die "tenant '$TENANT' has a live footprint on both '$FROM' and '$TO'"
        ;;
    esac
}

validate_source_inventory() {
    local namespace runner_sets listeners actual_runner_sets actual_listeners
    local listener_count unique_listener_count unexpected_listeners
    log_check "Comparing source ARC inventory with rendered runner sets $EXPECTED_RUNNER_NAMES_JSON."
    namespace=$(kubectl --context "$FROM_CTX" get namespace "$TENANT" \
        --ignore-not-found -o name) || die "unable to inspect source namespace on '$FROM'"
    if [[ -z "$namespace" ]]; then
        log_ok "Source namespace '$TENANT' is absent; there is no ARC inventory to drain."
        return
    fi

    runner_sets=$(kubectl --context "$FROM_CTX" --namespace "$TENANT" \
        get autoscalingrunnersets.actions.github.com -o json) ||
        die "unable to list source runner sets on '$FROM'"
    listeners=$(kubectl --context "$FROM_CTX" --namespace "$TENANT" \
        get autoscalinglisteners.actions.github.com -o json) ||
        die "unable to list source listeners on '$FROM'"

    actual_runner_sets=$(jq -c '[.items[].metadata.name] | sort' <<<"$runner_sets")
    actual_listeners=$(jq -c \
        '[.items[].metadata.labels["actions.github.com/scale-set-name"]] | sort' \
        <<<"$listeners")
    listener_count=$(jq 'length' <<<"$actual_listeners")
    unique_listener_count=$(jq 'unique | length' <<<"$actual_listeners")
    unexpected_listeners=$(jq -cn \
        --argjson actual "$actual_listeners" --argjson expected "$EXPECTED_RUNNER_NAMES_JSON" \
        '$actual - $expected')
    [[ "$actual_runner_sets" == "$EXPECTED_RUNNER_NAMES_JSON" &&
        "$listener_count" == "$unique_listener_count" &&
        "$unexpected_listeners" == '[]' ]] ||
        die "source ARC inventory differs from rendered config: expected=$EXPECTED_RUNNER_NAMES_JSON runner_sets=$actual_runner_sets listeners=$actual_listeners"
    log_ok "Source ARC inventory matches rendered runner sets $EXPECTED_RUNNER_NAMES_JSON."
}

preflight() {
    PHASE='preflight'
    local command_name actual_account configured_cluster configured_type migration_type
    log_phase 'Preflight'
    log_check 'Validating required commands and timeout settings.'
    for command_name in aws jq kubectl terragrunt yq; do
        require_command "$command_name"
    done
    [[ "$OPERATION_TIMEOUT_SECONDS" =~ ^[0-9]+$ &&
        "$DRAIN_TIMEOUT_SECONDS" =~ ^[0-9]+$ &&
        "$STABILITY_SECONDS" =~ ^[0-9]+$ &&
        "$QUIESCENCE_SECONDS" =~ ^[0-9]+$ &&
        "$POLL_SECONDS" =~ ^[0-9]+$ ]] ||
        die 'migration timeout and polling settings must be non-negative integers'
    log_ok 'Required commands and timeout settings are valid.'
    log_info "Timing: operation_timeout=${OPERATION_TIMEOUT_SECONDS}s drain_timeout=${DRAIN_TIMEOUT_SECONDS}s stability_window=${STABILITY_SECONDS}s quiet_window=${QUIESCENCE_SECONDS}s poll_interval=${POLL_SECONDS}s."

    log_check "Rendering Terragrunt inputs from '$TF_DIR'."
    render_inputs
    log_ok "Rendered tenant '$TENANT': profile=$AWS_PROFILE region=$AWS_REGION runner_sets=$EXPECTED_RUNNER_NAMES_JSON."

    log_check "Verifying AWS identity against account '$EXPECTED_ACCOUNT_ID'."
    actual_account=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)
    [[ "$actual_account" == "$EXPECTED_ACCOUNT_ID" ]] ||
        die "AWS account mismatch: expected $EXPECTED_ACCOUNT_ID, authenticated to $actual_account"
    log_ok "Authenticated to expected AWS account '$EXPECTED_ACCOUNT_ID'."

    log_check "Validating '$CONFIG_FILE' against rendered Terragrunt inputs."
    configured_type=$(yq -er '.arc_cluster_name | tag' "$CONFIG_FILE")
    migration_type=$(yq -er '.migrate_arc_cluster | tag' "$CONFIG_FILE")
    [[ "$configured_type" == '!!str' && "$migration_type" == '!!bool' ]] ||
        die 'arc_cluster_name must be a string and migrate_arc_cluster must be a boolean'
    configured_cluster=$(yq -er '.arc_cluster_name' "$CONFIG_FILE")
    [[ "$configured_cluster" == "$FROM" || "$configured_cluster" == "$TO" ]] ||
        die "configured cluster '$configured_cluster' is neither declared source '$FROM' nor destination '$TO'"
    [[ "$RENDERED_CLUSTER" == "$configured_cluster" ]] ||
        die "rendered ARC cluster '$RENDERED_CLUSTER' does not match config '$configured_cluster'"
    log_ok "Tenant config is valid and currently points to '$configured_cluster'."

    log_check "Refreshing kubeconfig for '$FROM' and '$TO'."
    aws eks update-kubeconfig --region "$AWS_REGION" --name "$FROM" \
        --alias "$FROM_CTX" --profile "$AWS_PROFILE" >/dev/null
    aws eks update-kubeconfig --region "$AWS_REGION" --name "$TO" \
        --alias "$TO_CTX" --profile "$AWS_PROFILE" >/dev/null
    log_ok 'Kubeconfig contexts are up to date.'

    log_check 'Checking both Kubernetes API readiness endpoints.'
    cluster_ready "$FROM_CTX" || die "source Kubernetes API is not ready: $FROM"
    cluster_ready "$TO_CTX" || die "destination Kubernetes API is not ready: $TO"
    log_ok 'Both Kubernetes APIs are ready.'

    log_check 'Detecting the live tenant ARC footprint on source and destination.'
    detect_live_mode
    if [[ "$LIVE_MODE" == move ]]; then
        validate_source_inventory
    fi

    if [[ "$NON_INTERACTIVE" != true ]]; then
        local expected_confirmation confirmation
        expected_confirmation="MIGRATE ${TENANT} ${FROM} TO ${TO}"
        log_info "About to migrate tenant '$TENANT' in AWS account '$EXPECTED_ACCOUNT_ID' ($AWS_REGION)."
        read -r -p "Type '$expected_confirmation' to continue: " confirmation
        [[ "$confirmation" == "$expected_confirmation" ]] || die 'confirmation did not match'
    fi

    log_ok "Preflight passed: tenant=$TENANT account=$EXPECTED_ACCOUNT_ID region=$AWS_REGION source=$FROM destination=$TO."
}

wait_until() {
    local description=$1 timeout_seconds=$2 deadline status started_at next_progress_at
    shift 2
    started_at=$SECONDS
    deadline=$((SECONDS + timeout_seconds))
    next_progress_at=$((SECONDS + WAIT_PROGRESS_SECONDS))
    log_wait "Waiting until $description (timeout ${timeout_seconds}s)."
    while true; do
        if "$@"; then
            log_ok "Confirmed: $description (elapsed $((SECONDS - started_at))s)."
            return
        else
            status=$?
        fi
        [[ "$status" == 1 ]] || die "unable to inspect state while waiting for $description"
        ((SECONDS < deadline)) ||
            die "timed out after ${timeout_seconds}s waiting until $description"
        if ((SECONDS >= next_progress_at)); then
            log_wait "Still waiting until $description (elapsed $((SECONDS - started_at))s of ${timeout_seconds}s timeout)."
            next_progress_at=$((SECONDS + WAIT_PROGRESS_SECONDS))
        fi
        sleep "$POLL_SECONDS"
    done
}

runner_pods_absent() {
    local context=$1 scale_set_name=$2 pods
    pods=$(kubectl --context "$context" --namespace "$TENANT" get pods -o json 2>/dev/null) || return 2
    jq -e --arg name "$scale_set_name" '
        [.items[]
            | select(.metadata.labels["actions.github.com/scale-set-name"] == $name)
            | select(.metadata.labels["app.kubernetes.io/component"] != "runner-scale-set-listener")]
        | length == 0
    ' <<<"$pods" >/dev/null
}

runner_set_quiesced() {
    local context=$1 scale_set_name=$2 listeners listener_name listener_uid pod
    listeners=$(kubectl --context "$context" --namespace "$TENANT" \
        get autoscalinglisteners.actions.github.com \
        -l "actions.github.com/scale-set-name=${scale_set_name}" -o json 2>/dev/null) || return 2
    if jq -e '.items | length == 0' <<<"$listeners" >/dev/null; then
        # ARC removes the old listener (and its pod via a finalizer) before it
        # may create the zero-capacity replacement. No listener is closed too.
        return 0
    fi
    jq -e '
        (.items | length) == 1 and
        .items[0].metadata.deletionTimestamp == null and
        (.items[0].spec.maxRunners // 0) == 0
    ' <<<"$listeners" >/dev/null || return 1

    listener_name=$(jq -er '.items[0].metadata.name' <<<"$listeners") || return 2
    listener_uid=$(jq -er '.items[0].metadata.uid' <<<"$listeners") || return 2
    pod=$(kubectl --context "$context" --namespace "$TENANT" \
        get pod "$listener_name" --ignore-not-found -o json 2>/dev/null) || return 2
    [[ -n "$pod" ]] || return 1
    jq -e --arg uid "$listener_uid" '
        .metadata.deletionTimestamp == null and
        .status.phase == "Running" and
        any(.metadata.ownerReferences[]?; .uid == $uid) and
        any(.status.conditions[]?; .type == "Ready" and .status == "True") and
        ([.status.containerStatuses[]?] | length) > 0 and
        all(.status.containerStatuses[]?; .ready == true)
    ' <<<"$pod" >/dev/null
}

all_runner_sets_quiesced() {
    local index runner_name status
    for ((index = 0; index < RUNNER_COUNT; index++)); do
        runner_name=${RUNNER_NAMES[$index]}
        if runner_set_quiesced "$FROM_CTX" "$runner_name"; then
            continue
        else
            status=$?
        fi
        return "$status"
    done
}

source_runner_snapshot() {
    local runners pods
    runners=$(kubectl --context "$FROM_CTX" --namespace "$TENANT" \
        get ephemeralrunners.actions.github.com -o json 2>/dev/null) || return 2
    pods=$(kubectl --context "$FROM_CTX" --namespace "$TENANT" \
        get pods -o json 2>/dev/null) || return 2
    jq -cs --argjson expected "$EXPECTED_RUNNER_NAMES_JSON" '
        [.[0].items[]
            | select(.metadata.labels["actions.github.com/scale-set-name"] as $name
                | $expected | index($name) != null)
            | "ephemeralrunner/\(.metadata.name)"] +
        [.[1].items[]
            | select(.metadata.labels["actions.github.com/scale-set-name"] as $name
                | $expected | index($name) != null)
            | select(.metadata.labels["app.kubernetes.io/component"] != "runner-scale-set-listener")
            | "pod/\(.metadata.name)"]
        | unique | sort
    ' <<<"$runners"$'\n'"$pods"
}

wait_for_source_quiescence() {
    local baseline current additions stable_since deadline status next_progress_at
    baseline=$(source_runner_snapshot) || die "unable to inspect source runners on '$FROM'"
    stable_since=$SECONDS
    deadline=$((SECONDS + OPERATION_TIMEOUT_SECONDS))
    next_progress_at=$((SECONDS + WAIT_PROGRESS_SECONDS))
    log_wait "Confirming source scheduling remains closed for ${QUIESCENCE_SECONDS}s (timeout ${OPERATION_TIMEOUT_SECONDS}s)."

    while ((SECONDS - stable_since < QUIESCENCE_SECONDS)); do
        if all_runner_sets_quiesced; then
            :
        else
            status=$?
            [[ "$status" == 1 ]] || die "unable to inspect source listeners on '$FROM'"
            stable_since=$SECONDS
        fi

        current=$(source_runner_snapshot) || die "unable to inspect source runners on '$FROM'"
        additions=$(jq -cn --argjson baseline "$baseline" --argjson current "$current" \
            '$current - $baseline')
        if [[ "$additions" != '[]' ]]; then
            log_warn "Source accepted additional runners during handoff; restarting quiet window: $additions"
            baseline=$(jq -cn --argjson baseline "$baseline" --argjson current "$current" \
                '$baseline + $current | unique | sort')
            stable_since=$SECONDS
        fi

        ((SECONDS < deadline)) ||
            die "source listeners did not remain quiesced for ${QUIESCENCE_SECONDS}s within ${OPERATION_TIMEOUT_SECONDS}s"
        if ((SECONDS >= next_progress_at)); then
            log_wait "Source quiet window progress: $((SECONDS - stable_since))/${QUIESCENCE_SECONDS}s."
            next_progress_at=$((SECONDS + WAIT_PROGRESS_SECONDS))
        fi
        sleep "$POLL_SECONDS"
    done
    log_ok "Source scheduling remained closed for ${QUIESCENCE_SECONDS}s."
}

runner_set_drained() {
    local context=$1 scale_set_name=$2 object runners runner_sets
    object=$(kubectl --context "$context" --namespace "$TENANT" \
        get autoscalingrunnerset.actions.github.com "$scale_set_name" --ignore-not-found -o json) || return 2
    [[ -n "$object" ]] || return 2
    jq -e '
        (.spec.minRunners // 0) == 0 and
        (.spec.maxRunners // 0) == 0
    ' <<<"$object" >/dev/null || return 1
    runner_set_quiesced "$context" "$scale_set_name" || return $?

    runners=$(kubectl --context "$context" --namespace "$TENANT" \
        get ephemeralrunners.actions.github.com \
        -l "actions.github.com/scale-set-name=${scale_set_name}" -o json 2>/dev/null) || return 2
    jq -e '.items | length == 0' <<<"$runners" >/dev/null || return 1

    runner_sets=$(kubectl --context "$context" --namespace "$TENANT" \
        get ephemeralrunnersets.actions.github.com \
        -l "actions.github.com/scale-set-name=${scale_set_name}" -o json 2>/dev/null) || return 2
    jq -e '
        all(.items[];
            (.spec.replicas // 0) == 0 and
            (.status.currentReplicas // 0) == 0 and
            (.status.pendingEphemeralRunners // 0) == 0 and
            (.status.runningEphemeralRunners // 0) == 0)
    ' <<<"$runner_sets" >/dev/null || return 1

    runner_pods_absent "$context" "$scale_set_name"
}

scale_down_runners() {
    PHASE="drain source cluster '$FROM'"
    local namespace runner_name index
    log_phase "Close source scheduling and drain jobs on '$FROM'"
    namespace=$(kubectl --context "$FROM_CTX" get namespace "$TENANT" --ignore-not-found -o name) ||
        die "unable to inspect namespace '$TENANT' on '$FROM'"
    if [[ -z "$namespace" ]]; then
        log_ok "Source namespace '$TENANT' is absent; no runners need draining."
        return
    fi

    log_info "Closing scheduling for $RUNNER_COUNT runner set(s) in namespace '$TENANT'."
    for ((index = 0; index < RUNNER_COUNT; index++)); do
        runner_name=${RUNNER_NAMES[$index]}
        log_check "Patching runner set '$runner_name' to minRunners=0 and maxRunners=0 ($((index + 1))/$RUNNER_COUNT)."
        kubectl --context "$FROM_CTX" --namespace "$TENANT" \
            patch autoscalingrunnerset.actions.github.com "$runner_name" \
            --type merge -p '{"spec":{"minRunners":0,"maxRunners":0}}' >/dev/null
        log_ok "Capacity-zero patch accepted for runner set '$runner_name'."
    done

    for ((index = 0; index < RUNNER_COUNT; index++)); do
        runner_name=${RUNNER_NAMES[$index]}
        wait_until "source scheduling is stopped for runner set '$runner_name' on '$FROM' ($((index + 1))/$RUNNER_COUNT)" \
            "$OPERATION_TIMEOUT_SECONDS" runner_set_quiesced "$FROM_CTX" "$runner_name"
    done
    wait_for_source_quiescence

    for ((index = 0; index < RUNNER_COUNT; index++)); do
        runner_name=${RUNNER_NAMES[$index]}
        wait_until "runner set '$runner_name' is fully drained on '$FROM' ($((index + 1))/$RUNNER_COUNT)" \
            "$DRAIN_TIMEOUT_SECONDS" runner_set_drained "$FROM_CTX" "$runner_name"
    done
    log_ok 'All source runner sets are drained.'
}

apply_arc() {
    PHASE=$1
    log_phase "$PHASE"
    log_apply 'Running Terragrunt apply for target module.arc_runners.'
    terragrunt apply --target module.arc_runners --working-dir "$TF_DIR" --non-interactive -auto-approve
    log_ok 'Terragrunt apply completed for target module.arc_runners.'
}

wait_for_clean_cluster() {
    local context=$1 cluster=$2 label=$3
    PHASE="verify $label cluster is clean"
    wait_until "$label cluster '$cluster' has no live tenant ARC footprint" \
        "$OPERATION_TIMEOUT_SECONDS" cluster_is_clean "$context" "$cluster"
    log_ok "Verified: $label cluster '$cluster' has no live tenant ARC footprint."
}

pod_logs_are_conflict_free() {
    local pod=$1 restart_count=$2 logs previous_logs
    logs=$(kubectl --context "$TO_CTX" --namespace "$TENANT" logs "$pod" --tail=200 2>&1) || return 1
    ! grep -Eqi 'RunnerScaleSetSessionConflictException|already has an active session|(^|[^0-9])409 Conflict' <<<"$logs" || return 1
    if ((restart_count > 0)); then
        previous_logs=$(kubectl --context "$TO_CTX" --namespace "$TENANT" logs "$pod" --previous --tail=200 2>&1 || true)
        ! grep -Eqi 'RunnerScaleSetSessionConflictException|already has an active session|(^|[^0-9])409 Conflict' <<<"$previous_logs" || return 1
    fi
}

destination_pod_snapshot() {
    local controllers listeners actual combined pod restart_count
    controllers=$(kubectl --context "$TO_CTX" --namespace "$TENANT" get pods \
        -l "app.kubernetes.io/instance=${DEPLOYMENT_PREFIX}" -o json 2>/dev/null) || return 1
    listeners=$(kubectl --context "$TO_CTX" --namespace "$TENANT" get pods \
        -l app.kubernetes.io/component=runner-scale-set-listener -o json 2>/dev/null) || return 1

    jq -e '
        (.items | length) == 1 and
        all(.items[];
            .metadata.deletionTimestamp == null and
            .status.phase == "Running" and
            any(.status.conditions[]?; .type == "Ready" and .status == "True") and
            ([.status.containerStatuses[]?] | length) > 0 and
            all(.status.containerStatuses[]?; .ready == true))
    ' <<<"$controllers" >/dev/null || return 1
    actual=$(jq -c '[.items[].metadata.labels["actions.github.com/scale-set-name"]] | sort' <<<"$listeners") || return 1
    [[ "$actual" == "$EXPECTED_RUNNER_NAMES_JSON" ]] || return 1
    jq -e '
        all(.items[];
            .metadata.deletionTimestamp == null and
            .status.phase == "Running" and
            any(.status.conditions[]?; .type == "Ready" and .status == "True") and
            ([.status.containerStatuses[]?] | length) > 0 and
            all(.status.containerStatuses[]?; .ready == true))
    ' <<<"$listeners" >/dev/null || return 1

    combined=$(jq -s '{items: (.[0].items + .[1].items)}' <<<"$controllers"$'\n'"$listeners") || return 1
    while IFS=$'\t' read -r pod restart_count; do
        [[ -n "$pod" ]] || continue
        pod_logs_are_conflict_free "$pod" "$restart_count" || return 1
    done < <(jq -r '.items[] | [.metadata.name, ([.status.containerStatuses[]?.restartCount // 0] | add // 0)] | @tsv' <<<"$combined")

    jq -c '
        [.items[] | {
            name: .metadata.name,
            uid: .metadata.uid,
            restarts: ([.status.containerStatuses[]?.restartCount // 0] | add // 0)
        }] | sort_by(.name)
    ' <<<"$combined"
}

verify_destination() {
    PHASE="verify destination cluster '$TO'"
    log_phase "Verify destination cluster '$TO'"
    log_wait "Waiting for destination controller '${DEPLOYMENT_PREFIX}-gha-rs-controller' to become available (timeout ${OPERATION_TIMEOUT_SECONDS}s)."
    kubectl --context "$TO_CTX" --namespace "$TENANT" wait \
        --for=condition=Available "deployment/${DEPLOYMENT_PREFIX}-gha-rs-controller" \
        --timeout="${OPERATION_TIMEOUT_SECONDS}s" >/dev/null
    log_ok 'Destination ARC controller is available.'

    log_wait "Waiting for destination NodePool 'karpenter-${TENANT}' to become Ready (timeout ${OPERATION_TIMEOUT_SECONDS}s)."
    kubectl --context "$TO_CTX" wait --for=condition=Ready "nodepool/karpenter-${TENANT}" \
        --timeout="${OPERATION_TIMEOUT_SECONDS}s" >/dev/null
    log_ok "Destination NodePool 'karpenter-${TENANT}' is Ready."

    log_wait "Waiting for destination EC2NodeClass 'karpenter-${TENANT}' to become Ready (timeout ${OPERATION_TIMEOUT_SECONDS}s)."
    kubectl --context "$TO_CTX" wait --for=condition=Ready "ec2nodeclass/karpenter-${TENANT}" \
        --timeout="${OPERATION_TIMEOUT_SECONDS}s" >/dev/null
    log_ok "Destination EC2NodeClass 'karpenter-${TENANT}' is Ready."

    local stable_since=-1 stable_snapshot='' candidate_snapshot deadline next_progress_at started_at
    started_at=$SECONDS
    deadline=$((SECONDS + OPERATION_TIMEOUT_SECONDS))
    next_progress_at=$((SECONDS + WAIT_PROGRESS_SECONDS))
    log_wait "Checking controller and listener health, restarts, and session-conflict logs for ${STABILITY_SECONDS}s (timeout ${OPERATION_TIMEOUT_SECONDS}s)."
    while ((SECONDS < deadline)); do
        if candidate_snapshot=$(
            trap - ERR
            destination_pod_snapshot
        ); then
            if [[ "$candidate_snapshot" != "$stable_snapshot" ]]; then
                if ((stable_since < 0)); then
                    log_info "Destination pods are healthy; starting ${STABILITY_SECONDS}s stability window."
                else
                    log_info "Destination pod identity changed; restarting ${STABILITY_SECONDS}s stability window."
                fi
                stable_snapshot=$candidate_snapshot
                stable_since=$SECONDS
            fi
            if ((SECONDS - stable_since >= STABILITY_SECONDS)); then
                wait_for_clean_cluster "$FROM_CTX" "$FROM" source
                log_ok "Verified: destination '$TO' is healthy and conflict-free for ${STABILITY_SECONDS}s."
                return
            fi
        else
            if ((stable_since >= 0)); then
                log_warn 'Destination health changed; restarting the stability window.'
            fi
            stable_snapshot=''
            stable_since=-1
        fi
        if ((SECONDS >= next_progress_at)); then
            log_wait "Still verifying destination health (elapsed $((SECONDS - started_at))s of ${OPERATION_TIMEOUT_SECONDS}s timeout)."
            next_progress_at=$((SECONDS + WAIT_PROGRESS_SECONDS))
        fi
        sleep "$POLL_SECONDS"
    done
    die "destination controller and listeners did not remain healthy and conflict-free for ${STABILITY_SECONDS}s within ${OPERATION_TIMEOUT_SECONDS}s"
}

main() {
    parse_args "$@"
    preflight

    log_phase 'Migration plan'
    log_info "Tenant: $TENANT"
    log_info "Source: $FROM"
    log_info "Destination: $TO"
    log_info "Mode: $LIVE_MODE"
    if ((RUNNER_COUNT == 0)); then
        [[ "$LIVE_MODE" == resume-after-source-cleanup ]] ||
            die "tenant '$TENANT' has no ARC runner sets but a live cluster footprint remains"
        PHASE='complete'
        log_phase 'Complete'
        log_ok "Tenant '$TENANT' has no ARC runner sets; no cluster migration is required."
        return
    fi

    if [[ "$LIVE_MODE" == move ]]; then
        # The return leg starts from the committed active-cluster value, so put
        # the local configuration on the explicitly declared live source first.
        update_config false "$FROM"
        scale_down_runners
        update_config true "$FROM"
        apply_arc "Disable ARC on source cluster '$FROM'"
        wait_for_clean_cluster "$FROM_CTX" "$FROM" source
    fi

    if [[ "$LIVE_MODE" != resume-destination ]]; then
        update_config true "$TO"
        apply_arc "Disable ARC on destination cluster '$TO'"
        wait_for_clean_cluster "$TO_CTX" "$TO" destination
    fi

    update_config false "$TO"
    apply_arc "Enable ARC on destination cluster '$TO'"
    verify_destination

    PHASE='complete'
    log_phase 'Complete'
    log_ok "Migration complete: tenant '$TENANT' is on '$TO' and absent from '$FROM'."
}

main "$@"
