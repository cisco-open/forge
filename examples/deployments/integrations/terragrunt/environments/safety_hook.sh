#!/bin/bash
################################################################################
# @brief:       Helper script to prevent accidental deployments (unless a
#               specific environment variable is set). This is to help prevent
#               engineers from accidentally doing something like
#               "cd path-that-is-not-dev; tf run-all apply".
#               If you're here, you probably need to run:
#               export TF_DANGEROUS=1
#               export TF_TARGET_ENV=prod
################################################################################
set -e
set -o pipefail
# set -x

ROOT_PATH="${1}"
NODE_PATH="${2}"

# echo "Paths:"
# echo "${ROOT_PATH}"
# echo "${NODE_PATH}"

DIFF="${NODE_PATH#"$ROOT_PATH"}"
# echo "Path difference:"
# echo "${DIFF}"

# Extract just the name of the folder representing the environment.
ENV="$(echo "${DIFF}" | cut -d '/' -f2)"
# echo "Environment: ${ENV}"

# Assumes no folders have spaces in them. Don't enable this for the "dev"
# environment, as that will just encourage engineers to write workarounds for
# this safety mechanism and ultimately defeat it.
PROTECTED_ENVIRONMENTS=(
    "stage"
    "prep"
    "prod"
)
# shellcheck disable=SC2076
if [[ " ${PROTECTED_ENVIRONMENTS[*]} " =~ " ${ENV} " ]]; then
    if [[ "${TF_DANGEROUS}" = "1" ]]; then
        # Override enabled. Do nothing; allow the operation to proceed.
        if [[ "${TF_TARGET_ENV}" = "${ENV}" ]]; then
            # User is targeting the correct/desired environment. Proceed.
            :
        else
            echo "Attempting to change environment without setting TF_TARGET_ENV correctly."
            echo "Currently detected environment: <<${ENV}>>"
            echo "Configured environment:         <<${TF_TARGET_ENV}>>"
            echo "Please refer to README.md"
            exit 1
        fi
    else
        echo "CRUD operations blocked unless TF_DANGEROUS is set correctly."
        echo "Please refer to README.md"
        exit 1
    fi
fi
