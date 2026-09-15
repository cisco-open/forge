#!/usr/bin/env bash
set -Eeuo pipefail

readonly DEFAULT_OPERATION_TIMEOUT_SECONDS=600
readonly DEFAULT_STABILITY_SECONDS=60
readonly DEFAULT_POLL_SECONDS=5

OPERATION_TIMEOUT_SECONDS="${ARC_MIGRATION_TIMEOUT_SECONDS:-$DEFAULT_OPERATION_TIMEOUT_SECONDS}"
STABILITY_SECONDS="${ARC_MIGRATION_STABILITY_SECONDS:-$DEFAULT_STABILITY_SECONDS}"
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
    yq e -i ".migrate_arc_cluster = $migrate_flag" "$CONFIG_FILE"
    yq e -i ".arc_cluster_name = \"$cluster_name\"" "$CONFIG_FILE"
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
        ;;
    0:0)
        LIVE_MODE=resume-after-source-cleanup
        echo 'Both clusters are clean; continuing with destination activation.'
        ;;
    0:1)
        LIVE_MODE=resume-destination
        echo "Source is clean and destination has the tenant; reconciling and validating '$TO'."
        ;;
    1:1)
        die "tenant '$TENANT' has a live footprint on both '$FROM' and '$TO'"
        ;;
    esac
}

preflight() {
    PHASE='preflight'
    local command_name actual_account configured_cluster configured_type migration_type
    for command_name in aws jq kubectl terragrunt yq; do
        require_command "$command_name"
    done

    render_inputs
    actual_account=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)
    [[ "$actual_account" == "$EXPECTED_ACCOUNT_ID" ]] ||
        die "AWS account mismatch: expected $EXPECTED_ACCOUNT_ID, authenticated to $actual_account"

    configured_type=$(yq -er '.arc_cluster_name | tag' "$CONFIG_FILE")
    migration_type=$(yq -er '.migrate_arc_cluster | tag' "$CONFIG_FILE")
    [[ "$configured_type" == '!!str' && "$migration_type" == '!!bool' ]] ||
        die 'arc_cluster_name must be a string and migrate_arc_cluster must be a boolean'
    configured_cluster=$(yq -er '.arc_cluster_name' "$CONFIG_FILE")
    [[ "$configured_cluster" == "$FROM" || "$configured_cluster" == "$TO" ]] ||
        die "configured cluster '$configured_cluster' is neither declared source '$FROM' nor destination '$TO'"
    [[ "$RENDERED_CLUSTER" == "$configured_cluster" ]] ||
        die "rendered ARC cluster '$RENDERED_CLUSTER' does not match config '$configured_cluster'"

    aws eks update-kubeconfig --region "$AWS_REGION" --name "$FROM" \
        --alias "$FROM_CTX" --profile "$AWS_PROFILE" >/dev/null
    aws eks update-kubeconfig --region "$AWS_REGION" --name "$TO" \
        --alias "$TO_CTX" --profile "$AWS_PROFILE" >/dev/null
    cluster_ready "$FROM_CTX" || die "source Kubernetes API is not ready: $FROM"
    cluster_ready "$TO_CTX" || die "destination Kubernetes API is not ready: $TO"
    detect_live_mode

    if [[ "$NON_INTERACTIVE" != true ]]; then
        local expected_confirmation confirmation
        expected_confirmation="MIGRATE ${TENANT} ${FROM} TO ${TO}"
        echo "About to migrate tenant '$TENANT' in AWS account '$EXPECTED_ACCOUNT_ID' ($AWS_REGION)."
        read -r -p "Type '$expected_confirmation' to continue: " confirmation
        [[ "$confirmation" == "$expected_confirmation" ]] || die 'confirmation did not match'
    fi

    echo "Preflight passed: tenant=$TENANT account=$EXPECTED_ACCOUNT_ID region=$AWS_REGION source=$FROM destination=$TO"
}

wait_until() {
    local description=$1 deadline
    shift
    deadline=$((SECONDS + OPERATION_TIMEOUT_SECONDS))
    until "$@"; do
        ((SECONDS < deadline)) || die "timed out waiting for $description"
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

runner_set_drained() {
    local context=$1 scale_set_name=$2 object
    object=$(kubectl --context "$context" --namespace "$TENANT" \
        get autoscalingrunnerset.actions.github.com "$scale_set_name" --ignore-not-found -o json) || return 2
    [[ -z "$object" ]] && return 0
    jq -e '
        (.status.currentRunners // 0) == 0 and
        (.status.pendingEphemeralRunners // 0) == 0 and
        (.status.runningEphemeralRunners // 0) == 0
    ' <<<"$object" >/dev/null && runner_pods_absent "$context" "$scale_set_name"
}

scale_down_runners() {
    PHASE="drain source cluster '$FROM'"
    local namespace runner_name index
    namespace=$(kubectl --context "$FROM_CTX" get namespace "$TENANT" --ignore-not-found -o name) ||
        die "unable to inspect namespace '$TENANT' on '$FROM'"
    if [[ -z "$namespace" ]]; then
        echo "Source namespace '$TENANT' is absent; no runners to drain."
        return
    fi

    echo "Scaling down runner sets in namespace '$TENANT'."
    for ((index = 0; index < RUNNER_COUNT; index++)); do
        runner_name=${RUNNER_NAMES[$index]}
        if kubectl --context "$FROM_CTX" --namespace "$TENANT" \
            get autoscalingrunnerset.actions.github.com "$runner_name" >/dev/null 2>&1; then
            echo "Scaling down runner set: $runner_name"
            kubectl --context "$FROM_CTX" --namespace "$TENANT" \
                patch autoscalingrunnerset.actions.github.com "$runner_name" \
                --type merge -p '{"spec":{"minRunners":0,"maxRunners":0}}' >/dev/null
        fi
    done

    for ((index = 0; index < RUNNER_COUNT; index++)); do
        runner_name=${RUNNER_NAMES[$index]}
        wait_until "runner set '$runner_name' to drain on '$FROM'" \
            runner_set_drained "$FROM_CTX" "$runner_name"
    done
    echo 'All source runner sets are drained.'
}

apply_arc() {
    PHASE=$1
    echo "Applying Terragrunt target: module.arc_runners ($PHASE)"
    terragrunt apply --target module.arc_runners --working-dir "$TF_DIR" --non-interactive -auto-approve
}

wait_for_clean_cluster() {
    local context=$1 cluster=$2 label=$3
    PHASE="verify $label cluster is clean"
    wait_until "$label cluster '$cluster' to have no live tenant ARC footprint" \
        cluster_is_clean "$context" "$cluster"
    echo "Verified: $label cluster '$cluster' has no live tenant ARC footprint."
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
    if ((RUNNER_COUNT == 0)); then
        wait_for_clean_cluster "$TO_CTX" "$TO" destination
        wait_for_clean_cluster "$FROM_CTX" "$FROM" source
        echo "Verified: tenant '$TENANT' has no ARC runner sets configured."
        return
    fi

    kubectl --context "$TO_CTX" --namespace "$TENANT" wait \
        --for=condition=Available "deployment/${DEPLOYMENT_PREFIX}-gha-rs-controller" \
        --timeout="${OPERATION_TIMEOUT_SECONDS}s" >/dev/null
    kubectl --context "$TO_CTX" wait --for=condition=Ready "nodepool/karpenter-${TENANT}" \
        --timeout="${OPERATION_TIMEOUT_SECONDS}s" >/dev/null
    kubectl --context "$TO_CTX" wait --for=condition=Ready "ec2nodeclass/karpenter-${TENANT}" \
        --timeout="${OPERATION_TIMEOUT_SECONDS}s" >/dev/null

    local stable_since=-1 stable_snapshot='' candidate_snapshot deadline
    deadline=$((SECONDS + OPERATION_TIMEOUT_SECONDS))
    while ((SECONDS < deadline)); do
        if candidate_snapshot=$(
            trap - ERR
            destination_pod_snapshot
        ); then
            if [[ "$candidate_snapshot" != "$stable_snapshot" ]]; then
                stable_snapshot=$candidate_snapshot
                stable_since=$SECONDS
            fi
            if ((SECONDS - stable_since >= STABILITY_SECONDS)); then
                wait_for_clean_cluster "$FROM_CTX" "$FROM" source
                echo "Verified: destination '$TO' is healthy and conflict-free."
                return
            fi
        else
            stable_snapshot=''
            stable_since=-1
        fi
        sleep "$POLL_SECONDS"
    done
    die "destination controller and listeners did not remain healthy and conflict-free for ${STABILITY_SECONDS}s"
}

main() {
    parse_args "$@"
    preflight

    echo "Migrating tenant '$TENANT' from '$FROM' to '$TO'."
    if [[ "$LIVE_MODE" == move ]]; then
        # The return leg starts from the committed active-cluster value, so put
        # the local configuration on the explicitly declared live source first.
        update_config false "$FROM"
        scale_down_runners
        update_config true "$FROM"
        apply_arc "disable ARC on source cluster '$FROM'"
        wait_for_clean_cluster "$FROM_CTX" "$FROM" source
    fi

    if [[ "$LIVE_MODE" != resume-destination ]]; then
        update_config true "$TO"
        apply_arc "disable ARC on destination cluster '$TO'"
        wait_for_clean_cluster "$TO_CTX" "$TO" destination
    fi

    update_config false "$TO"
    apply_arc "enable ARC on destination cluster '$TO'"
    verify_destination

    PHASE='complete'
    echo "Migration complete: tenant '$TENANT' is on '$TO' and absent from '$FROM'."
}

main "$@"
