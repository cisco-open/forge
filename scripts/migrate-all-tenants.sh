#!/bin/bash
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SCRIPT="$SCRIPT_DIR/migrate-tenant.sh"
TENANTS_DIR=$1

for tenant in "$TENANTS_DIR"/*; do
    if [ -d "$tenant" ]; then
        echo ">>> Migrating tenant: $(basename "$tenant")"
        "$SCRIPT" --tf-dir "$tenant"
    fi
done
