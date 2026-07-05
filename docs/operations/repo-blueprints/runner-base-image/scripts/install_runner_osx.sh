#!/bin/bash

set -euo pipefail

if [[ -z "${RUNNER_USER:-}" ]]; then
    echo "RUNNER_USER environment variable must be set." >&2
    exit 1
fi

if [[ -z "${RUNNER_TARBALL_URL:-}" ]]; then
    echo "RUNNER_TARBALL_URL environment variable must be set." >&2
    exit 1
fi

RUNNER_ROOT="${RUNNER_ROOT:-/opt/actions-runner}"
TMP_DIR="$(mktemp -d)"
ARCHIVE_PATH="${TMP_DIR}/actions-runner.tar.gz"

cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

if ! id "${RUNNER_USER}" >/dev/null 2>&1; then
    echo "Runner user '${RUNNER_USER}' does not exist." >&2
    exit 1
fi

echo "Installing GitHub Actions runner to ${RUNNER_ROOT}"
rm -rf "${RUNNER_ROOT}"
mkdir -p "${RUNNER_ROOT}"

echo "Downloading GitHub Actions runner package from ${RUNNER_TARBALL_URL}"
curl -fsSL "${RUNNER_TARBALL_URL}" -o "${ARCHIVE_PATH}"

echo "Extracting runner archive to ${RUNNER_ROOT}"
tar -xzf "${ARCHIVE_PATH}" -C "${RUNNER_ROOT}"

if [[ ! -f "${RUNNER_ROOT}/config.sh" ]]; then
    echo "Runner archive extracted, but config.sh was not found in ${RUNNER_ROOT}." >&2
    exit 1
fi

chown -R "${RUNNER_USER}":staff "${RUNNER_ROOT}"

TOOLCACHE_HOME="/Users/runner"
TOOLCACHE_DIR="${TOOLCACHE_HOME}/hostedtoolcache"
mkdir -p "${TOOLCACHE_DIR}"
chown root:wheel "${TOOLCACHE_HOME}"
chown "${RUNNER_USER}":staff "${TOOLCACHE_DIR}"
chmod 755 "${TOOLCACHE_HOME}" "${TOOLCACHE_DIR}"

cat >"${RUNNER_ROOT}/.env" <<EOF
AGENT_TOOLSDIRECTORY=${TOOLCACHE_DIR}
RUNNER_TOOL_CACHE=${TOOLCACHE_DIR}
EOF
chown "${RUNNER_USER}":staff "${RUNNER_ROOT}/.env"
chmod 0644 "${RUNNER_ROOT}/.env"

echo "GitHub Actions runner installed to ${RUNNER_ROOT}"
