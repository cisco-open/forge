#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
DEPS_SCRIPT="${TG_DEPS_SCRIPT:-${SCRIPT_DIR}/terragrunt-deps.py}"
PYTHON_BIN="${PYTHON_BIN:-python3.12}"

debug() {
    case "${DEBUG:-}" in
    1 | true | TRUE | yes | YES | on | ON)
        printf 'DEBUG: %s\n' "$*" >&2
        ;;
    esac
}

find_stack_root() {
    local dir="$1"

    debug "Looking for Terragrunt stack root from: $dir"

    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/root.hcl" ]]; then
            debug "Found Terragrunt stack root: $dir"
            printf '%s\n' "$dir"
            return 0
        fi

        dir=$(dirname "$dir")
    done

    debug "No root.hcl found; using module dir as stack root: $1"
    printf '%s\n' "$1"
}

find_dependents() {
    local orig_dir="$1"
    local stack_root
    local deps_json
    local deps_output
    local deps_parser
    local dep
    local normalized_dep

    stack_root="${TG_STACK_ROOT:-$(find_stack_root "$orig_dir")}"
    stack_root=$(cd "$stack_root" && pwd -P)

    debug "Finding dependents for module directory: $orig_dir"
    debug "Using Terragrunt stack root: $stack_root"
    debug "Using dependency script: $DEPS_SCRIPT"

    deps_json=$(
        "$PYTHON_BIN" "$DEPS_SCRIPT" "$orig_dir" \
            --working-dir "$stack_root"
    )

    deps_parser='import json, sys; '
    deps_parser+='sys.stdout.write("\n".join('
    deps_parser+='json.load(sys.stdin).get("deps", [])))'
    deps_output=$("$PYTHON_BIN" -c "$deps_parser" <<<"$deps_json")

    while IFS= read -r dep; do
        [[ -z "$dep" ]] && continue

        case "$dep" in
        /*)
            normalized_dep="$dep"
            ;;
        .)
            normalized_dep="$stack_root"
            ;;
        *)
            normalized_dep="${stack_root}/${dep}"
            ;;
        esac

        debug "Found dependent '${dep}', normalized path: ${normalized_dep}"
        printf '%s\n' "$normalized_dep"
    done <<<"$deps_output"
}

# Function to apply modules and their dependents
apply_with_deps() {
    local orig_dir
    local dep
    orig_dir=$(pwd -P)

    debug "Starting create/apply workflow from: $orig_dir"
    echo ">>> Applying main module: $orig_dir"
    terragrunt apply -auto-approve --non-interactive

    while IFS= read -r dep; do
        debug "Applying dependent module from: $dep"
        echo ">>> Applying dependent module: $dep"
        pushd "$dep" >/dev/null
        terragrunt apply -auto-approve --non-interactive
        popd >/dev/null
        debug "Returned to original module directory: $orig_dir"
    done < <(find_dependents "$orig_dir")
}

# Function to destroy modules and their dependents
destroy_with_deps() {
    local orig_dir
    local dep
    orig_dir=$(pwd -P)

    debug "Starting destroy workflow from: $orig_dir"

    # Destroy dependents before the current module.
    while IFS= read -r dep; do
        debug "Destroying dependent module from: $dep"
        echo ">>> Destroying dependent module: $dep"
        pushd "$dep" >/dev/null
        terragrunt destroy -auto-approve --non-interactive
        popd >/dev/null
        debug "Returned to original module directory: $orig_dir"
    done < <(find_dependents "$orig_dir")

    echo ">>> Destroying current module: $orig_dir"
    terragrunt destroy -auto-approve --non-interactive
}

# Function to show usage
usage() {
    echo "Usage: $0 {create|destroy}"
    echo "  create  - Apply main module and its dependents"
    echo "  destroy - Destroy dependents and main module"
    echo "  DEBUG=1 - Print debug output to stderr"
    echo "  PYTHON_BIN=python3.12 - Python binary for deps"
    echo "  TG_DEPS_SCRIPT=<path> - Override dependency resolver script"
    exit 1
}

# Main script logic
case "${1:-}" in
create | apply)
    apply_with_deps
    ;;
destroy)
    destroy_with_deps
    ;;
*)
    usage
    ;;
esac
