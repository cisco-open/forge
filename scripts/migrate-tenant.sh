#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 --tf-dir <terragrunt directory> --context <k8s context alias>"
    exit 1
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --tf-dir)
            TF_DIR="$2"
            shift 2
            ;;
        --context)
            FROM_CTX="$2"
            shift 2
            ;;
        *)
            echo "Unknown arg: $1"
            usage
            ;;
        esac
    done

    [[ -z "${TF_DIR:-}" || -z "${FROM_CTX:-}" ]] && usage

    TENANT=$(basename "$TF_DIR")
    [[ -z "${TENANT:-}" ]] && {
        echo "Error: Could not determine tenant from directory '$TF_DIR'"
        exit 1
    }
    CONFIG_FILE="${TF_DIR}/config.yml"
}

detect_clusters() {
    CURRENT_CLUSTER=$(yq e '.arc_cluster_name' "$CONFIG_FILE")

    if [[ "$CURRENT_CLUSTER" == *"-green" ]]; then
        FROM="$CURRENT_CLUSTER"
        TO="${CURRENT_CLUSTER%-green}-blue"
    elif [[ "$CURRENT_CLUSTER" == *"-blue" ]]; then
        FROM="$CURRENT_CLUSTER"
        TO="${CURRENT_CLUSTER%-blue}-green"
    else
        echo "Cannot detect blue/green suffix in arc_cluster_name: $CURRENT_CLUSTER"
        exit 1
    fi
}

scale_down_runners() {
    echo "🧯 Scaling down runners in namespace: $TENANT"
    for key in $(yq -r '.arc_runner_specs | keys | .[]' "$CONFIG_FILE"); do
        echo "Checking runner set: $key"
        if kubectl --context "$FROM_CTX" get autoscalingrunnersets.actions.github.com -n "$TENANT" "$key" &>/dev/null; then
            echo "Scaling down runner set: $key"
            kubectl --context "$FROM_CTX" patch autoscalingrunnersets.actions.github.com -n "$TENANT" "$key" --type merge -p '{"spec":{"minRunners":0,"maxRunners":0}}'
        else
            echo "Runner set $key not found, skipping."
        fi
    done

    echo "⏳ Waiting for runner pods to terminate..."
    while kubectl --context "$FROM_CTX" get pods -n "$TENANT" | grep -q runner; do
        sleep 5
    done
}

terragrunt_apply() {
    local target="$1"
    echo "🔧 Applying Terragrunt target: $target"
    terragrunt apply --target "$target" -working-dir "$TF_DIR" -non-interactive -auto-approve
}

update_config() {
    local migrate_flag="$1"
    local cluster_name="$2"

    yq e -i ".migrate_arc_cluster = $migrate_flag" "$CONFIG_FILE"
    yq e -i ".arc_cluster_name = \"$cluster_name\"" "$CONFIG_FILE"
}

main() {
    parse_args "$@"
    detect_clusters

    echo "🔄 Migrating tenant '$TENANT' from '$FROM' to '$TO'..."
    echo "📄 Editing config: $CONFIG_FILE"
    echo "🔍 Using Kubernetes context: $FROM_CTX"

    # Step 1
    scale_down_runners

    # Step 2
    echo "🛑 Disabling ARC for tenant on old cluster '$FROM'"
    update_config true "$FROM"
    terragrunt_apply 'module.arc_runners'

    # Step 3
    echo "🚀 Enabling ARC for tenant on new cluster '$TO'"
    update_config false "$TO"
    terragrunt_apply 'module.arc_runners'

    echo "✅ Migration complete. Tenant '$TENANT' is now on '$TO'"
}

main "$@"
