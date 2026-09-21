#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SCRIPT="$SCRIPT_DIR/migrate-tenant.sh"

if [[ $# -lt 4 ]]; then
    echo "Usage: $0 TENANTS_DIR FROM_CLUSTER TO_CLUSTER EXPECTED_ACCOUNT_ID [migrate-tenant options]" >&2
    exit 1
fi

TENANTS_DIR=$1
FROM_CLUSTER=$2
TO_CLUSTER=$3
EXPECTED_ACCOUNT_ID=$4
shift 4

for tenant in "$TENANTS_DIR"/*; do
    if [[ -d "$tenant" ]]; then
        config="${tenant}/config.yml"
        [[ -f "$config" ]] || {
            echo "Skipping $(basename "$tenant"): config.yml is absent."
            continue
        }
        echo ">>> Migrating tenant: $(basename "$tenant")"
        "$SCRIPT" \
            --tf-dir "$tenant" \
            --from-cluster "$FROM_CLUSTER" \
            --to-cluster "$TO_CLUSTER" \
            --expected-account-id "$EXPECTED_ACCOUNT_ID" \
            "$@"
    fi
done
