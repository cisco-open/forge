#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <terragrunt_dir> <type> <value>"
    echo "  <type>: key | id | installation_id | name | client_id"
    echo "  <value>: For 'key' type, path to PEM file to base64 encode. For others, string value."
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

get_secret_name() {
    local terragrunt_dir="$1"
    local type="$2"
    terragrunt output -json --working-dir "$terragrunt_dir" | jq -r --arg t "$type" '
    .tenant.value as $tenant |
    "/cicd/common/\($tenant.name)/\($tenant.vpc_alias)/github_actions_runners_app_" + $t
  '
}

encode_pem() {
    local pem_file="$1"
    tr -d '\n' <"$pem_file" | base64
}

update_secret() {
    local secret_name="$1"
    local secret_value="$2"
    aws secretsmanager put-secret-value --secret-id "$secret_name" --secret-string "$secret_value"
}

main() {
    if [[ $# -ne 3 ]]; then
        usage
    fi

    TERRAGRUNT_DIR="$1"
    TYPE="$2"
    VALUE="$3"

    case "$TYPE" in
    key | id | installation_id | name | client_id) ;;
    *)
        echo "Error: Invalid type '$TYPE'. Allowed: key, id, installation_id, name"
        exit 1
        ;;
    esac

    validate_terragrunt_dir "$TERRAGRUNT_DIR"

    if [[ "$TYPE" == "key" ]]; then
        validate_pem_file "$VALUE"
        SECRET_VALUE=$(encode_pem "$VALUE")
    else
        SECRET_VALUE="$VALUE"
    fi

    SECRET_NAME=$(get_secret_name "$TERRAGRUNT_DIR" "$TYPE")

    update_secret "$SECRET_NAME" "$SECRET_VALUE"

    echo "✅ Updated secret '$SECRET_NAME'"
}

main "$@"
