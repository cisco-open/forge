#!/usr/bin/env bash
# args: role_arn, source_profile, new_profile_name, region

ROLE_ARN="$1"
SOURCE_PROFILE="$2"
NEW_PROFILE="$3"
REGION="$4"

# Assume the role using AWS CLI
CREDS_JSON=$(aws sts assume-role \
    --role-arn "$ROLE_ARN" \
    --role-session-name terraform-session \
    --profile "$SOURCE_PROFILE" \
    --region "$REGION" \
    --output json)

# Extract credentials
ACCESS_KEY=$(echo "$CREDS_JSON" | jq -r '.Credentials.AccessKeyId')
SECRET_KEY=$(echo "$CREDS_JSON" | jq -r '.Credentials.SecretAccessKey')
SESSION_TOKEN=$(echo "$CREDS_JSON" | jq -r '.Credentials.SessionToken')

# Add or overwrite the temporary profile in ~/.aws/credentials
aws configure set aws_access_key_id "$ACCESS_KEY" --profile "$NEW_PROFILE"
aws configure set aws_secret_access_key "$SECRET_KEY" --profile "$NEW_PROFILE"
aws configure set aws_session_token "$SESSION_TOKEN" --profile "$NEW_PROFILE"
aws configure set region "$REGION" --profile "$NEW_PROFILE"

echo "{\"profile\":\"$NEW_PROFILE\"}"
