#!/usr/bin/env bash
set -euo pipefail

AWS_PROFILE="${1}"
AWS_REGION="${2}"
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

    # Region filter: include bucket only if REGION matches AWS_REGION, or wildcard/empty
    if [[ "$REGION" == "$AWS_REGION" ]]; then
        # Try to get KMS key ID
        KMS_KEY=$(aws s3api get-bucket-encryption \
            --profile "${AWS_PROFILE}" \
            --bucket "$BUCKET" \
            --query "ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.KMSMasterKeyID" \
            --output text 2>/dev/null || echo "")

        ITEM=$(jq -n --arg name "$BUCKET" --arg region "$REGION" --arg kms "$KMS_KEY" '{name: $name, region: $region, kms: $kms}')
        RESULT=$(echo "$RESULT" | jq ". + [$ITEM]")
    fi
done

ENCODED_STRING=$(jq -n --argjson arr "$RESULT" '$arr | @json')

echo "{\"buckets\": $ENCODED_STRING}"
