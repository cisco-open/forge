#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <terragrunt_dir> <pem_file>"
    echo "  <terragrunt_dir>: Path to the Terragrunt directory for the tenant/stack"
    echo "  <pem_file>: Path to the GitHub App PEM file to base64 encode and store in SSM"
    exit 1
}

validate_terragrunt_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || {
        echo "Error: Terragrunt directory '$dir' does not exist."
        exit 1
    }
}

validate_pem_file() {
    local file="$1"
    [[ -f "$file" ]] || {
        echo "Error: PEM file '$file' does not exist."
        exit 1
    }
}

get_ssm_name() {
    local terragrunt_dir="$1"
    local deployment_prefix
    deployment_prefix=$(get_terragrunt_var "var.deployment_config.deployment_prefix" "$terragrunt_dir")
    echo "/forge/${deployment_prefix}/github_app_key"
}

get_terragrunt_var() {
    local var_name="$1"
    local dir="$2"
    local value

    pushd "$dir" >/dev/null
    value=$(TF_LOG=ERROR terragrunt console <<<"${var_name}" 2>/dev/null | tail -n1 | sed 's/^"//;s/"$//')
    popd >/dev/null

    if [[ -z "$value" ]]; then
        echo "❌ Terragrunt variable '${var_name}' not found or empty in ${dir}" >&2
        exit 1
    fi

    echo "$value"
}

encode_pem() {
    local pem_file="$1"
    tr -d '\n' <"$pem_file" | base64
}

update_ssm_param() {
    local param_name="$1"
    local param_value="$2"
    aws ssm put-parameter \
        --name "$param_name" \
        --type "SecureString" \
        --value "$param_value" \
        --overwrite
}

main() {
    if [[ $# -ne 2 ]]; then
        usage
    fi

    TERRAGRUNT_DIR="$1"
    PEM_FILE="$2"

    validate_terragrunt_dir "$TERRAGRUNT_DIR"
    validate_pem_file "$PEM_FILE"

    SSM_NAME=$(get_ssm_name "$TERRAGRUNT_DIR")
    ENCODED_KEY=$(encode_pem "$PEM_FILE")

    update_ssm_param "$SSM_NAME" "$ENCODED_KEY"

    echo "✅ Updated SSM parameter '$SSM_NAME' with base64-encoded GitHub App key"
}

main "$@"
