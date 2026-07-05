#!/bin/bash

set -euo pipefail

RUNNER_USER="${RUNNER_USER:-ec2-user}"
RUNNER_ROOT="${RUNNER_ROOT:-/opt/actions-runner}"
RUNNER_ENV="${RUNNER_ROOT}/.env"
TOOLCACHE_HOME="/Users/runner"
TOOLCACHE_DIR="${TOOLCACHE_HOME}/hostedtoolcache"

if ! id "${RUNNER_USER}" >/dev/null 2>&1; then
    echo "Runner user '${RUNNER_USER}' does not exist; skipping toolcache setup." >&2
    exit 0
fi

mkdir -p "${TOOLCACHE_DIR}"
chown root:wheel "${TOOLCACHE_HOME}"
chown "${RUNNER_USER}":staff "${TOOLCACHE_DIR}"
chmod 755 "${TOOLCACHE_HOME}" "${TOOLCACHE_DIR}"

if [[ -d "${RUNNER_ROOT}" ]]; then
    {
        echo "AGENT_TOOLSDIRECTORY=${TOOLCACHE_DIR}"
        echo "RUNNER_TOOL_CACHE=${TOOLCACHE_DIR}"
    } >"${RUNNER_ENV}"
    chown "${RUNNER_USER}":staff "${RUNNER_ENV}"
    chmod 0644 "${RUNNER_ENV}"
fi

if ! sudo -u "${RUNNER_USER}" test -w "${TOOLCACHE_DIR}"; then
    echo "${TOOLCACHE_DIR} is not writable by ${RUNNER_USER}." >&2
    exit 1
fi
