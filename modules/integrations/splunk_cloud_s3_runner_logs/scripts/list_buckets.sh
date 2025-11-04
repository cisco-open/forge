#!/usr/bin/env bash
set -euo pipefail

AWS_PROFILE="${1}"
SUFFIX="forge-gh-logs"

# Get buckets as JSON array
BUCKETS_JSON=$(aws s3api list-buckets \
    --profile "${AWS_PROFILE}" \
    --query "Buckets[?contains(Name, '${SUFFIX}')] | [].Name" \
    --output json)

RESULT="[]"

# Iterate over JSON array
for BUCKET in $(echo "$BUCKETS_JSON" | jq -r '.[]'); do
    REGION=$(aws s3api get-bucket-location \
        --profile "${AWS_PROFILE}" \
        --bucket "$BUCKET" \
        --query "LocationConstraint" \
        --output text)
    if [[ "$REGION" == "None" ]]; then
        REGION="us-east-1"
    fi
    ITEM=$(jq -n --arg name "$BUCKET" --arg region "$REGION" '{name: $name, region: $region}')
    RESULT=$(echo "$RESULT" | jq ". + [$ITEM]")
done

# Encode the array as JSON string
ENCODED=$(jq -n --argjson buckets "$RESULT" '$buckets | @json')

# Wrap in an object
echo "{\"buckets\": $ENCODED}"
