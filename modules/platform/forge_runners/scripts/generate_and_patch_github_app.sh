#!/usr/bin/env bash
#shellcheck disable=SC2086,SC2004

set -euo pipefail

DEBUG="${DEBUG:-true}"

log() {
    # Mask secrets by showing only length
    local msg="$1"
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $msg"
}

if [[ "${DEBUG}" == "true" ]]; then
    log "Debug enabled"
    log "Environment snapshot:"
    log "CLIENT_ID (len) = ${CLIENT_ID:+${#CLIENT_ID}}"
    log "PRIVATE_KEY (len) = ${PRIVATE_KEY:+${#PRIVATE_KEY}}"
    log "GITHUB_API=${GITHUB_API:-unset}"
    log "WEBHOOK_URL=${WEBHOOK_URL:-unset}"
    log "SECRET (len) = ${SECRET:+${#SECRET}}"
fi

now=$(date +%s)
iat=$((${now} - 60))  # Issues 60 seconds in the past
exp=$((${now} + 600)) # Expires 10 minutes in the future

log "now=${now} iat=${iat} exp=${exp} (ttl=$((exp - now))s)"

b64enc() { openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n'; }

header_json='{
    "typ":"JWT",
    "alg":"RS256"
}'
log "Header JSON: ${header_json}"
# Header encode
header=$(echo -n "${header_json}" | b64enc)
log "Header (b64 len)=${#header}"

payload_json="{
    \"iat\":${iat},
    \"exp\":${exp},
    \"iss\":\"${CLIENT_ID}\"
}"
log "Payload JSON: ${payload_json}"
# Payload encode
payload=$(echo -n "${payload_json}" | b64enc)
log "Payload (b64 len)=${#payload}"

# Signature
header_payload="${header}"."${payload}"
log "Header.Payload (len)=${#header_payload}"

# Show first 30 chars for sanity
log "Header.Payload (preview)=${header_payload:0:30}..."

signature=$(
    openssl dgst -sha256 -sign <(echo -n "${PRIVATE_KEY}") \
        <(echo -n "${header_payload}") | b64enc
)
log "Signature (b64 len)=${#signature}"

# Create JWT
JWT="${header_payload}"."${signature}"
log "JWT constructed (len)=${#JWT}"

# Optional local validation (exp > now)
if ((exp <= now)); then
    log "ERROR: exp is not in the future"
    exit 1
fi

LOG_FILE="/tmp/${PREFIX}-github_api_response.log"
REQ_FILE="/tmp/${PREFIX}-github_api_request.json"

request_body=$(
    cat <<EOF
{
  "url": "${WEBHOOK_URL}",
  "content_type": "json",
  "insecure_ssl": "0",
  "secret": "${SECRET}"
}
EOF
)

echo "${request_body}" >"${REQ_FILE}"
log "Request body written to ${REQ_FILE} (size $(wc -c <"${REQ_FILE}") bytes)"

log "PATCH ${GITHUB_API}/app/hook/config"
response=$(curl -s -D "/tmp/${PREFIX}-github_api_headers.txt" -o "/tmp/${PREFIX}-github_api_body.txt" -w "%{http_code}" -X PATCH "${GITHUB_API}/app/hook/config" \
    -H "Authorization: Bearer $JWT" \
    -H "Accept: application/vnd.github+json" \
    -H "Content-Type: application/json" \
    --data-binary @"${REQ_FILE}")

http_code="${response}"
log "HTTP status=${http_code}"

if [[ "${DEBUG}" == "true" ]]; then
    log "Response headers:"
    sed 's/^/  /' "/tmp/${PREFIX}-github_api_headers.txt"
fi

tee "${LOG_FILE}" <"/tmp/${PREFIX}-github_api_body.txt" >/dev/null
log "Response body saved to ${LOG_FILE} (size $(wc -c <"${LOG_FILE}") bytes)"

if [[ "${http_code}" -ge 200 && "${http_code}" -lt 300 ]]; then
    log "Success"
else
    log "Failure (non-2xx). See ${LOG_FILE}"
    exit 1
fi
