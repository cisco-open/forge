#!/usr/bin/env bash
set -euo pipefail

# Function to apply modules and their dependencies
apply_with_deps() {
    local orig_dir
    orig_dir=$(pwd)
    local deps

    # Get dependent modules (absolute paths)
    deps=$(terragrunt render --format json | jq -r '.dependent_modules[]')

    echo ">>> Applying main module: $orig_dir"
    terragrunt apply -auto-approve --non-interactive

    for dep in $deps; do
        echo ">>> Applying dependency: $dep"
        pushd "$dep" >/dev/null
        terragrunt apply -auto-approve --non-interactive
        popd >/dev/null
    done
}

# Function to destroy modules and their dependencies
destroy_with_deps() {
    local orig_dir
    orig_dir=$(pwd)
    local deps

    # Get dependent modules (absolute paths)
    deps=$(terragrunt render --format json | jq -r '.dependent_modules[]')

    # Destroy dependencies first (reverse order)
    for dep in $deps; do
        echo ">>> Destroying dependency: $dep"
        pushd "$dep" >/dev/null
        terragrunt destroy -auto-approve --non-interactive
        popd >/dev/null
    done

    echo ">>> Destroying current module: $orig_dir"
    terragrunt destroy -auto-approve --non-interactive
}

# Function to show usage
usage() {
    echo "Usage: $0 {create|destroy}"
    echo "  create  - Apply main module and its dependencies"
    echo "  destroy - Destroy dependencies and main module"
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
