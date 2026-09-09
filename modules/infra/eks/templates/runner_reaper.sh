#!/bin/sh

set -u
set -f
umask 077

readonly ARS_RESOURCE="autoscalingrunnersets.actions.github.com"
readonly ER_RESOURCE="ephemeralrunners.actions.github.com"
readonly SCOPES_FILE="/tmp/runner-reaper-scopes.$$"
readonly NAMESPACES_FILE="/tmp/runner-reaper-namespaces.$$"
readonly CANDIDATES_FILE="/tmp/runner-reaper-candidates.$$"
readonly ACTIONS_FILE="/tmp/runner-reaper-actions.$$"
readonly SERVICE_ACCOUNT_DIR="${RUNNER_REAPER_SERVICE_ACCOUNT_DIR:-/var/run/secrets/kubernetes.io/serviceaccount}"
GENERATED_KUBECONFIG=

log() {
    level=$1
    shift
    printf '%s level=%s component=arc-runner-reaper cluster=%s %s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$level" "$CLUSTER_NAME" "$*"
}

cleanup() {
    rm -f "$SCOPES_FILE" "$NAMESPACES_FILE" "$CANDIDATES_FILE" "$ACTIONS_FILE"
    if [ -n "$GENERATED_KUBECONFIG" ]; then
        rm -f "$GENERATED_KUBECONFIG"
    fi
}

trap cleanup EXIT HUP INT TERM
for temporary_file in "$SCOPES_FILE" "$NAMESPACES_FILE" "$CANDIDATES_FILE" "$ACTIONS_FILE"; do
    : >"$temporary_file"
done

parse_timestamp() {
    timestamp=$1

    date -d "$timestamp" +%s 2>/dev/null && return 0

    # BSD date fallback keeps the script useful for operator-side dry runs.
    case "$timestamp" in
    *.*) timestamp_without_fraction=${timestamp%%.*}Z ;;
    *) timestamp_without_fraction=$timestamp ;;
    esac
    date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$timestamp_without_fraction" +%s 2>/dev/null
}

configure_in_cluster_kubectl() {
    if [ -n "${KUBECONFIG:-}" ]; then
        return 0
    fi

    service_host=${KUBERNETES_SERVICE_HOST:-}
    service_port=${KUBERNETES_SERVICE_PORT_HTTPS:-${KUBERNETES_SERVICE_PORT:-}}
    if [ -z "$service_host" ] || [ -z "$service_port" ]; then
        return 0
    fi

    for service_account_file in ca.crt token; do
        if [ ! -r "$SERVICE_ACCOUNT_DIR/$service_account_file" ]; then
            log ERROR "result=abort reason=service-account-$service_account_file-unreadable"
            return 1
        fi
    done

    GENERATED_KUBECONFIG="/tmp/runner-reaper-kubeconfig.$$"
    export KUBECONFIG="$GENERATED_KUBECONFIG"
    {
        printf '%s\n' 'apiVersion: v1' 'kind: Config' 'clusters:'
        printf '%s\n' '- cluster:'
        printf '    certificate-authority: %s/ca.crt\n' "$SERVICE_ACCOUNT_DIR"
        printf '    server: "https://%s:%s"\n' "$service_host" "$service_port"
        printf '%s\n' '  name: in-cluster' 'contexts:' '- context:'
        printf '%s\n' '    cluster: in-cluster' '    user: service-account'
        printf '%s\n' '  name: in-cluster' 'current-context: in-cluster' 'users:'
        printf '%s\n' '- name: service-account' '  user:'
        printf '    tokenFile: %s/token\n' "$SERVICE_ACCOUNT_DIR"
    } >"$GENERATED_KUBECONFIG" || {
        log ERROR "result=abort reason=kubeconfig-write-failed"
        return 1
    }
}

probe_runner() {
    namespace=$1
    runner_name=$2
    expected_job_id=$3

    assignment=$(kubectl --request-timeout=30s get "$ER_RESOURCE" "$runner_name" \
        --namespace "$namespace" \
        --output jsonpath='{.status.phase}{"|"}{.status.jobId}' 2>/dev/null) || {
        log WARN "namespace=$namespace runner=$runner_name job_id=$expected_job_id result=skip reason=ephemeralrunner-read-failed" >&2
        return 1
    }

    current_phase=${assignment%%|*}
    current_job_id=${assignment#*|}
    if [ "$current_phase" != "Running" ] || [ "$current_job_id" != "$expected_job_id" ]; then
        return 1
    fi

    # The single-quoted program is intentionally evaluated inside the runner container.
    # shellcheck disable=SC2016
    probe_result=$(kubectl --request-timeout=30s exec \
        --namespace "$namespace" \
        --container runner \
        "$runner_name" \
        -- sh -c '
            stale_after=$1

            not_stale() {
                printf "not-stale:%s\n" "$1"
                exit 0
            }

            for required_command in date find grep ps sort stat tail; do
                command -v "$required_command" >/dev/null 2>&1 || not_stale "missing-$required_command"
            done

            runner_logs=$(find /home/runner/_diag -maxdepth 1 -type f -name "Runner_*.log" -print 2>/dev/null) || not_stale "runner-log-scan-failed"
            [ -n "$runner_logs" ] || not_stale "no-runner-log"

            latest_log=$(printf "%s\n" "$runner_logs" | sort | tail -n 1)
            ack_found=false
            for runner_log in $runner_logs; do
                if grep -Fqs "Acknowledging runner request" "$runner_log"; then
                    ack_found=true
                    break
                fi
            done
            [ "$ack_found" = true ] || not_stale "no-acknowledgement"

            worker_log=$(find /home/runner/_diag -type f -name "Worker_*.log" -print -quit 2>/dev/null) || not_stale "worker-log-scan-failed"
            [ -z "$worker_log" ] || not_stale "worker-log-present"

            processes=$(ps -eo args 2>/dev/null) || not_stale "process-scan-failed"
            if printf "%s\n" "$processes" | grep -q "[R]unner[.]Worker"; then
                not_stale "worker-process-present"
            fi

            last_write=$(stat -c %Y "$latest_log" 2>/dev/null) || not_stale "runner-log-stat-failed"
            now=$(date +%s) || not_stale "clock-read-failed"
            case "$last_write:$now:$stale_after" in
                *[!0-9:]*) not_stale "invalid-timestamp" ;;
            esac

            age=$((now - last_write))
            [ "$age" -ge "$stale_after" ] || not_stale "runner-log-recent"
            printf "stale:%s\n" "$age"
        ' _ "$STALE_AFTER_SECONDS" 2>/dev/null) || {
        log WARN "namespace=$namespace runner=$runner_name job_id=$expected_job_id result=skip reason=pod-exec-failed" >&2
        return 1
    }

    case "$probe_result" in
    stale:*)
        printf '%s\n' "${probe_result#stale:}"
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

case "$DRY_RUN" in
true | false) ;;
*)
    log ERROR "result=abort reason=invalid-dry-run-value"
    exit 1
    ;;
esac

for numeric_value in \
    "$STALE_AFTER_SECONDS" \
    "$CONFIRMATION_DELAY_SECONDS" \
    "$MAX_PROBES_PER_NAMESPACE" \
    "$MAX_PROBES_PER_RUN" \
    "$MAX_DELETIONS_PER_NAMESPACE" \
    "$MAX_DELETIONS_PER_RUN"; do
    case "$numeric_value" in
    '' | *[!0-9]*)
        log ERROR "result=abort reason=invalid-numeric-configuration"
        exit 1
        ;;
    esac
done

if [ -z "$CLUSTER_NAME" ]; then
    log ERROR "result=abort reason=empty-cluster-name"
    exit 1
fi

configure_in_cluster_kubectl || exit 1

log INFO "mode=$([ "$DRY_RUN" = true ] && printf observe || printf delete) scope=all-arc-tenants stale_after_seconds=$STALE_AFTER_SECONDS confirmation_delay_seconds=$CONFIRMATION_DELAY_SECONDS max_probes_per_namespace=$MAX_PROBES_PER_NAMESPACE max_probes_per_run=$MAX_PROBES_PER_RUN max_deletions_per_namespace=$MAX_DELETIONS_PER_NAMESPACE max_deletions_per_run=$MAX_DELETIONS_PER_RUN"

scope_lines=$(kubectl --request-timeout=30s get "$ARS_RESOURCE" \
    --all-namespaces \
    --sort-by .metadata.namespace \
    --output jsonpath='{range .items[*]}{.metadata.namespace}{"|"}{.metadata.name}{"\n"}{end}') || {
    log ERROR "result=abort reason=autoscalingrunnerset-list-failed"
    exit 1
}

while IFS='|' read -r namespace scale_set_name; do
    [ -n "$namespace" ] && [ -n "$scale_set_name" ] || continue
    case "$namespace:$scale_set_name" in
    *[!a-z0-9.:-]*)
        log WARN "namespace=$namespace scale_set=$scale_set_name result=skip reason=invalid-scope-name"
        continue
        ;;
    esac
    printf '%s|%s\n' "$namespace" "$scale_set_name" >>"$SCOPES_FILE"
done <<EOF
$scope_lines
EOF

if [ ! -s "$SCOPES_FILE" ]; then
    log INFO "result=complete tenants=0 scale_sets=0 candidates=0 probes=0 actions=0"
    exit 0
fi

sort -u "$SCOPES_FILE" -o "$SCOPES_FILE"
cut -d '|' -f 1 "$SCOPES_FILE" | sort -u >"$NAMESPACES_FILE"

tenant_count=$(grep -c '^' "$NAMESPACES_FILE")
scale_set_count=$(grep -c '^' "$SCOPES_FILE")
probes=0
candidates=0
errors=0
stop_probing=false
now=$(date +%s)

while IFS= read -r namespace; do
    [ "$stop_probing" = false ] || break

    scale_sets=
    while IFS='|' read -r scope_namespace scale_set_name; do
        [ "$scope_namespace" = "$namespace" ] || continue
        if [ -z "$scale_sets" ]; then
            scale_sets=$scale_set_name
        else
            scale_sets="$scale_sets,$scale_set_name"
        fi
    done <"$SCOPES_FILE"

    candidate_lines=$(kubectl --request-timeout=30s get "$ER_RESOURCE" \
        --namespace "$namespace" \
        --selector "actions.github.com/scale-set-name in ($scale_sets)" \
        --sort-by .metadata.creationTimestamp \
        --output jsonpath='{range .items[?(@.status.phase=="Running")]}{.metadata.name}{"|"}{.status.jobId}{"|"}{.metadata.creationTimestamp}{"\n"}{end}') || {
        log ERROR "namespace=$namespace result=skip reason=ephemeralrunner-list-failed"
        errors=$((errors + 1))
        continue
    }

    namespace_probes=0
    while IFS='|' read -r runner_name job_id created_at; do
        [ -n "$runner_name" ] && [ -n "$job_id" ] && [ -n "$created_at" ] || continue

        case "$runner_name" in
        *[!a-z0-9.-]*)
            log WARN "namespace=$namespace result=skip reason=invalid-runner-name"
            continue
            ;;
        esac

        created_epoch=$(parse_timestamp "$created_at") || {
            log WARN "namespace=$namespace runner=$runner_name job_id=$job_id result=skip reason=creation-timestamp-parse-failed"
            continue
        }
        resource_age=$((now - created_epoch))
        [ "$resource_age" -ge "$STALE_AFTER_SECONDS" ] || continue

        if [ "$namespace_probes" -ge "$MAX_PROBES_PER_NAMESPACE" ]; then
            log WARN "namespace=$namespace result=probe-limit-reached max_probes_per_namespace=$MAX_PROBES_PER_NAMESPACE"
            break
        fi
        if [ "$probes" -ge "$MAX_PROBES_PER_RUN" ]; then
            log WARN "result=probe-limit-reached max_probes_per_run=$MAX_PROBES_PER_RUN"
            stop_probing=true
            break
        fi
        namespace_probes=$((namespace_probes + 1))
        probes=$((probes + 1))

        if log_age=$(probe_runner "$namespace" "$runner_name" "$job_id"); then
            printf '%s|%s|%s\n' "$namespace" "$runner_name" "$job_id" >>"$CANDIDATES_FILE"
            candidates=$((candidates + 1))
            log INFO "namespace=$namespace runner=$runner_name job_id=$job_id result=candidate runner_log_age_seconds=$log_age check=1"
        fi
    done <<EOF
$candidate_lines
EOF
done <"$NAMESPACES_FILE"

if [ ! -s "$CANDIDATES_FILE" ]; then
    if [ "$errors" -gt 0 ]; then
        log ERROR "result=incomplete tenants=$tenant_count scale_sets=$scale_set_count candidates=0 probes=$probes actions=0 errors=$errors"
        exit 1
    fi
    log INFO "result=complete tenants=$tenant_count scale_sets=$scale_set_count candidates=0 probes=$probes actions=0"
    exit 0
fi

sleep "$CONFIRMATION_DELAY_SECONDS"

actions=0
while IFS='|' read -r namespace runner_name job_id; do
    if [ "$actions" -ge "$MAX_DELETIONS_PER_RUN" ]; then
        log WARN "result=deletion-limit-reached max_deletions_per_run=$MAX_DELETIONS_PER_RUN"
        break
    fi

    namespace_actions=$(grep -Fxc "$namespace" "$ACTIONS_FILE")
    if [ "$namespace_actions" -ge "$MAX_DELETIONS_PER_NAMESPACE" ]; then
        log WARN "namespace=$namespace result=deletion-limit-reached max_deletions_per_namespace=$MAX_DELETIONS_PER_NAMESPACE"
        continue
    fi

    if ! log_age=$(probe_runner "$namespace" "$runner_name" "$job_id"); then
        log INFO "namespace=$namespace runner=$runner_name job_id=$job_id result=skip reason=second-check-not-stale"
        continue
    fi

    if [ "$DRY_RUN" = true ]; then
        log WARN "namespace=$namespace runner=$runner_name job_id=$job_id result=would-delete runner_log_age_seconds=$log_age check=2"
    elif kubectl --request-timeout=30s delete "$ER_RESOURCE" "$runner_name" \
        --namespace "$namespace" \
        --wait=false; then
        log WARN "namespace=$namespace runner=$runner_name job_id=$job_id result=deleted runner_log_age_seconds=$log_age check=2"
    else
        log ERROR "namespace=$namespace runner=$runner_name job_id=$job_id result=delete-failed"
        errors=$((errors + 1))
        continue
    fi

    printf '%s\n' "$namespace" >>"$ACTIONS_FILE"
    actions=$((actions + 1))
done <"$CANDIDATES_FILE"

if [ "$errors" -gt 0 ]; then
    log ERROR "result=incomplete tenants=$tenant_count scale_sets=$scale_set_count candidates=$candidates probes=$probes actions=$actions errors=$errors"
    exit 1
fi

log INFO "result=complete tenants=$tenant_count scale_sets=$scale_set_count candidates=$candidates probes=$probes actions=$actions"
