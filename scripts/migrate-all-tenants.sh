#!/bin/bash
SCRIPT="./migrate-tenant.sh"
TENANTS_DIR=$1

for tenant in "$TENANTS_DIR"/*; do
    if [ -d "$tenant" ]; then
        echo ">>> Migrating tenant: $(basename "$tenant")"
        "$SCRIPT" --tf-dir "$tenant"
    fi
done
