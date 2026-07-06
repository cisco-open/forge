#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${ROOT}/rendered"
CSS_FILE="${ROOT}/architecture-group-colors.css"
ICON_PACK_DIR="${ROOT}/icon-packs"
ICON_PORT="${ICON_PORT:-8123}"
ICON_URL="http://127.0.0.1:${ICON_PORT}/aws-forge-icons.json"
MMDC="${MMDC:-mmdc}"
PUPPETEER_CONFIG="${PUPPETEER_CONFIG:-${ROOT}/puppeteer-config.json}"

mkdir -p "${OUT_DIR}"

python3 - "${ICON_PACK_DIR}" "${ICON_PORT}" <<'PY' &
import functools
import http.server
import socketserver
import sys

directory = sys.argv[1]
port = int(sys.argv[2])

class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()

socketserver.ThreadingTCPServer.allow_reuse_address = True
handler = functools.partial(Handler, directory=directory)
with socketserver.ThreadingTCPServer(("127.0.0.1", port), handler) as httpd:
    httpd.serve_forever()
PY

ICON_SERVER_PID=$!

cleanup() {
    kill "${ICON_SERVER_PID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 0.5

render_markdown() {
    local name="$1"
    shift || true

    "${MMDC}" \
        -i "${ROOT}/${name}.md" \
        -o "${OUT_DIR}/${name}.png" \
        -p "${PUPPETEER_CONFIG}" \
        -C "${CSS_FILE}" \
        -b '#ffffff' \
        --iconPacksNamesAndUrls "aws-forge#${ICON_URL}" \
        "$@"

    if [[ -f "${OUT_DIR}/${name}-1.png" ]]; then
        mv -f "${OUT_DIR}/${name}-1.png" "${OUT_DIR}/${name}.png"
    fi
}

render_markdown 10k_ft_multi_tenant
render_markdown 10k_ft_tenant
render_markdown 10k_ft
render_markdown forge_runner_ec2
render_markdown forge_runner_eks
render_markdown forge_architecture -w 2400 -H 1800
