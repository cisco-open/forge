#!/usr/bin/env bash
set -euo pipefail

READER_ROLE_ARN="$1"
SOURCE_ROLE_ARN="$2"
SOURCE_SECRET_ARN="$3"
AWS_PROFILE="$4"
AWS_REGION="$5"

############################################
# 1. Assume the reader role (first hop)
############################################
aws sts assume-role \
    --role-arn "$READER_ROLE_ARN" \
    --role-session-name reader-temp \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --query 'Credentials' \
    --output json >/tmp/reader-creds.json

aws configure set aws_access_key_id "$(jq -r .AccessKeyId /tmp/reader-creds.json)" --profile reader-temp
aws configure set aws_secret_access_key "$(jq -r .SecretAccessKey /tmp/reader-creds.json)" --profile reader-temp
aws configure set aws_session_token "$(jq -r .SessionToken /tmp/reader-creds.json)" --profile reader-temp

############################################
# 2. Assume the external secret source role (second hop)
############################################
aws sts assume-role \
    --role-arn "$SOURCE_ROLE_ARN" \
    --role-session-name source-temp \
    --profile reader-temp \
    --region "$AWS_REGION" \
    --query 'Credentials' \
    --output json >/tmp/source-creds.json

aws configure set aws_access_key_id "$(jq -r .AccessKeyId /tmp/source-creds.json)" --profile source-temp
aws configure set aws_secret_access_key "$(jq -r .SecretAccessKey /tmp/source-creds.json)" --profile source-temp
aws configure set aws_session_token "$(jq -r .SessionToken /tmp/source-creds.json)" --profile source-temp

############################################
# 3. Use the final profile for AWS calls
############################################
SECRET_VALUE=$(aws secretsmanager get-secret-value \
    --secret-id "$SOURCE_SECRET_ARN" \
    --region "$AWS_REGION" \
    --query 'SecretString' \
    --profile source-temp \
    --output text)

# 4. Return as JSON to Terraform
jq -n --arg secret_value "$SECRET_VALUE" '{"secret_value":$secret_value}'
