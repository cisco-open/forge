#!/usr/bin/env bash
set -euo pipefail

find_stack_root() {
    local dir="$1"

    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/root.hcl" ]]; then
            printf '%s\n' "$dir"
            return 0
        fi

        dir=$(dirname "$dir")
    done

    printf '%s\n' "$1"
}

terragrunt_find_filter() {
    local stack_root="$1"
    local filter="$2"
    local stderr_file
    local status

    stderr_file=$(mktemp "${TMPDIR:-/tmp}/terragrunt-find.XXXXXX")

    if terragrunt find --working-dir "$stack_root" --filter "$filter" 2>"$stderr_file"; then
        if [[ -s "$stderr_file" ]]; then
            cat "$stderr_file" >&2
        fi
        rm -f "$stderr_file"
        return 0
    fi

    status=$?

    if grep -q "filter-flag" "$stderr_file"; then
        rm -f "$stderr_file"
        terragrunt find --experiment=filter-flag --working-dir "$stack_root" --filter "$filter"
        return $?
    fi

    cat "$stderr_file" >&2
    rm -f "$stderr_file"
    return "$status"
}

find_dependents() {
    local orig_dir="$1"
    local stack_root
    local unit_name
    local dep

    stack_root="${TG_STACK_ROOT:-$(find_stack_root "$orig_dir")}"
    stack_root=$(cd "$stack_root" && pwd -P)
    unit_name=$(basename "$orig_dir")

    while IFS= read -r dep; do
        [[ -z "$dep" ]] && continue

        case "$dep" in
        /*)
            printf '%s\n' "$dep"
            ;;
        .)
            printf '%s\n' "$stack_root"
            ;;
        *)
            printf '%s/%s\n' "$stack_root" "$dep"
            ;;
        esac
    done < <(terragrunt_find_filter "$stack_root" "...^${unit_name}")
}

# Function to apply modules and their dependents
apply_with_deps() {
    local orig_dir
    local dep
    orig_dir=$(pwd -P)

    echo ">>> Applying main module: $orig_dir"
    terragrunt apply -auto-approve --non-interactive

    while IFS= read -r dep; do
        echo ">>> Applying dependent module: $dep"
        pushd "$dep" >/dev/null
        terragrunt apply -auto-approve --non-interactive
        popd >/dev/null
    done < <(find_dependents "$orig_dir")
}

# Function to destroy modules and their dependents
destroy_with_deps() {
    local orig_dir
    local dep
    orig_dir=$(pwd -P)

    # Destroy dependents before the current module.
    while IFS= read -r dep; do
        echo ">>> Destroying dependent module: $dep"
        pushd "$dep" >/dev/null
        terragrunt destroy -auto-approve --non-interactive
        popd >/dev/null
    done < <(find_dependents "$orig_dir")

    echo ">>> Destroying current module: $orig_dir"
    terragrunt destroy -auto-approve --non-interactive
}

# Function to show usage
usage() {
    echo "Usage: $0 {create|destroy}"
    echo "  create  - Apply main module and its dependents"
    echo "  destroy - Destroy dependents and main module"
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
