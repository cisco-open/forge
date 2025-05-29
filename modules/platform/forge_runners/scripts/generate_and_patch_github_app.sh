#!/usr/bin/env bash
#shellcheck disable=SC2086,SC2004
set -o pipefail

now=$(date +%s)
iat=$((${now} - 60))  # Issues 60 seconds in the past
exp=$((${now} + 600)) # Expires 10 minutes in the future

b64enc() { openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n'; }

header_json='{
    "typ":"JWT",
    "alg":"RS256"
}'
# Header encode
header=$(echo -n "${header_json}" | b64enc)

payload_json="{
    \"iat\":${iat},
    \"exp\":${exp},
    \"iss\":\"${CLIENT_ID}\"
}"
# Payload encode
payload=$(echo -n "${payload_json}" | b64enc)

# Signature
header_payload="${header}"."${payload}"
signature=$(
    openssl dgst -sha256 -sign <(echo -n "${PRIVATE_KEY}") \
        <(echo -n "${header_payload}") | b64enc
)

# Create JWT
JWT="${header_payload}"."${signature}"

# Call GitHub API
LOG_FILE="/tmp/github_api_response.log"

response=$(curl -s -X PATCH "${GITHUB_API}/app/hook/config" \
    -H "Authorization: Bearer $JWT" \
    -H "Accept: application/vnd.github+json" \
    -H "Content-Type: application/json" \
    -d "{
    \"url\": \"$WEBHOOK_URL\",
    \"content_type\": \"json\",
    \"insecure_ssl\": \"0\",
    \"secret\": \"$SECRET\"
  }")

echo "$response" | tee "$LOG_FILE"
echo "Response saved to $LOG_FILE"
