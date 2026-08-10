#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 apply|remove" >&2
}

require_common_environment() {
    : "${AWS_REGION:?AWS_REGION must be set}"
    : "${STREAM_NAME_PREFIX:?STREAM_NAME_PREFIX must be set}"
    : "${TAG_COUNT:?TAG_COUNT must be set}"
}

resolve_metric_stream_arn() {
    local matching_output
    local candidate_arn
    local -a matching_arns=()

    if ! matching_output="$(aws cloudwatch list-metric-streams \
        --region "$AWS_REGION" \
        --query "max_by(Entries[?starts_with(Name, '$STREAM_NAME_PREFIX')], &CreationDate).Arn" \
        --output text)"; then
        return 2
    fi

    while IFS= read -r candidate_arn; do
        if [ -n "$candidate_arn" ] && [ "$candidate_arn" != "None" ]; then
            matching_arns+=("$candidate_arn")
        fi
    done < <(printf '%s\n' "$matching_output" | tr '\t' '\n')

    if [ "${#matching_arns[@]}" -eq 0 ]; then
        return 1
    fi

    if [ "${#matching_arns[@]}" -ne 1 ]; then
        echo "Expected one newest CloudWatch Metric Stream with prefix '$STREAM_NAME_PREFIX'; query returned ${#matching_arns[@]}." >&2
        printf '  %s\n' "${matching_arns[@]}" >&2
        return 2
    fi

    printf '%s\n' "${matching_arns[0]}"
}

apply_tags() {
    local attempt
    local output
    local resolve_status
    local resource_arn
    local max_attempts=60
    local retry_seconds=15

    if [ "$TAG_COUNT" -eq 0 ]; then
        echo "No CloudWatch Metric Stream tags to apply."
        return 0
    fi

    : "${TAGS_JSON:?TAGS_JSON must be set when applying tags}"

    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
        resource_arn=""

        if resource_arn="$(resolve_metric_stream_arn)"; then
            echo "Applying $TAG_COUNT tag(s) to CloudWatch Metric Stream: $resource_arn"

            if output="$(aws cloudwatch tag-resource \
                --region "$AWS_REGION" \
                --resource-arn "$resource_arn" \
                --tags "$TAGS_JSON" 2>&1)"; then
                return 0
            fi

            if [[ "$output" != *"ResourceNotFoundException"* ]]; then
                echo "$output" >&2
                return 1
            fi
        else
            resolve_status="$?"
            if [ "$resolve_status" -ne 1 ]; then
                return "$resolve_status"
            fi
        fi

        if [ "$attempt" -eq "$max_attempts" ]; then
            echo "CloudWatch Metric Stream with prefix '$STREAM_NAME_PREFIX' was not available after $max_attempts attempts." >&2
            return 1
        fi

        echo "CloudWatch Metric Stream with prefix '$STREAM_NAME_PREFIX' is not available yet; retrying in $retry_seconds seconds."
        sleep "$retry_seconds"
    done
}

remove_tags() {
    local output
    local resolve_status
    local resource_arn

    if [ "$TAG_COUNT" -eq 0 ]; then
        echo "No CloudWatch Metric Stream tags to remove."
        return 0
    fi

    : "${TAG_KEYS_JSON:?TAG_KEYS_JSON must be set when removing tags}"
    resource_arn=""

    if resource_arn="$(resolve_metric_stream_arn)"; then
        :
    else
        resolve_status="$?"

        if [ "$resolve_status" -eq 1 ]; then
            echo "CloudWatch Metric Stream no longer exists; no tags remain to remove."
            return 0
        fi

        return "$resolve_status"
    fi

    echo "Removing previously managed tags from CloudWatch Metric Stream: $resource_arn"

    if output="$(aws cloudwatch untag-resource \
        --region "$AWS_REGION" \
        --resource-arn "$resource_arn" \
        --tag-keys "$TAG_KEYS_JSON" 2>&1)"; then
        return 0
    fi

    if [[ "$output" == *"ResourceNotFoundException"* ]]; then
        echo "CloudWatch Metric Stream no longer exists; no tags remain to remove."
        return 0
    fi

    echo "$output" >&2
    return 1
}

main() {
    if [ "$#" -ne 1 ]; then
        usage
        return 2
    fi

    case "$1" in
    apply | remove) ;;
    *)
        usage
        return 2
        ;;
    esac

    require_common_environment

    case "$1" in
    apply)
        apply_tags
        ;;
    remove)
        remove_tags
        ;;
    esac
}

main "$@"
