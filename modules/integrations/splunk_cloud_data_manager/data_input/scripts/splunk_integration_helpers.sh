#!/bin/bash

splunk_input_uses_s3() {
    jq -e '.details.datasetInfo | has("s3-custom-logs")' "$1" >/dev/null 2>&1
}

splunk_validate_input_response() {
    jq -e '(.details.datasetInfo | type) == "object"' "$1" >/dev/null 2>&1
}

splunk_s3_input_matches_request() {
    jq -e --slurpfile expected "$2" '
        $expected[0] as $request
        | .name == $request.name
        and .type == $request.type
        and .destination == $request.destination
        and .mode == $request.mode
        and (.details | {
            type,
            iamRegion,
            datasetInfo,
            dataAccounts,
            s3BucketPatterns,
            kmsKeyArns
        }) == ($request.details | {
            type,
            iamRegion,
            datasetInfo,
            dataAccounts,
            s3BucketPatterns,
            kmsKeyArns
        })
    ' "$1" >/dev/null 2>&1
}

splunk_s3_input_matches_version() {
    jq -e --arg expected_version "$2" '
        (.details.version? | tostring) == $expected_version
    ' "$1" >/dev/null 2>&1
}

splunk_s3_input_matches_update_time() {
    jq -e --arg expected_update_time "$2" '
        .lastUpdateTime? == $expected_update_time
    ' "$1" >/dev/null 2>&1
}

splunk_s3_input_state() {
    jq -r '
        (.details.datasetInfo["s3-custom-logs"].sqsUrls? // []) as $sqs_sources
        | (.id? // ._key? // "") as $input_id
        | [
            $sqs_sources[].sqsUrl
            | capture("^https://sqs\\.(?<region>[^.]+)\\.amazonaws\\.com(?:\\.cn)?/[0-9]+/(?<queue>[^/?#]+)$")
            | "scc_\(.region)_\(.queue)_\($input_id)"
        ] as $expected_status_keys
        | (.dataSourcesStatus // {} | to_entries) as $status_entries
        | [
            $expected_status_keys[] as $expected_key
            | [
                $status_entries[]
                | select(.key == $expected_key)
                | (.value.status.state? // empty)
            ]
        ] as $states_by_source
        | [$states_by_source[][]] as $states
        | if any($states[]; test("(fail|error)"; "i")) then
            "failed"
        elif ((.details.stackName? // "") | length) == 0 or .details.version? == null then
            "pending"
        elif ($input_id | length) == 0
            or ($expected_status_keys | length) != ($sqs_sources | length)
            or ($expected_status_keys | length) == 0
            or any($states_by_source[]; length == 0) then
            "pending"
        elif all($states_by_source[]; any(.[]; endswith("Success"))) then
            "ready"
        else
            "pending"
        end
    ' "$1"
}

splunk_wait_for_s3_input() {
    input_file="$1"
    fetch_function="$2"
    log_file="$3"
    max_attempts="${4:-60}"
    poll_interval_seconds="${5:-5}"
    request_file="${6:-}"
    expected_version="${7:-}"
    expected_update_time="${8:-}"

    attempt=1
    if [ -s "$input_file" ]; then
        needs_fetch=false
    else
        needs_fetch=true
    fi

    while [ "$attempt" -le "$max_attempts" ]; do
        if [ "$needs_fetch" = true ]; then
            "$fetch_function"
            fetch_status=$?

            if [ "$fetch_status" -eq 2 ]; then
                echo "Splunk data input request failed with a non-retryable HTTP response." >>"$log_file"
                return 1
            elif [ "$fetch_status" -ne 0 ]; then
                if [ "$attempt" -eq "$max_attempts" ]; then
                    echo "Splunk S3 data source was not ready after $max_attempts attempts." >>"$log_file"
                    return 1
                fi

                sleep "$poll_interval_seconds"
                attempt=$((attempt + 1))
                continue
            fi
        fi

        if ! splunk_validate_input_response "$input_file"; then
            echo "Splunk returned an invalid data input response." >>"$log_file"
            return 1
        fi

        if ! splunk_input_uses_s3 "$input_file"; then
            return 0
        fi

        if { [ -n "$request_file" ] && ! splunk_s3_input_matches_request "$input_file" "$request_file"; } ||
            { [ -n "$expected_version" ] && ! splunk_s3_input_matches_version "$input_file" "$expected_version"; } ||
            { [ -n "$expected_update_time" ] && ! splunk_s3_input_matches_update_time "$input_file" "$expected_update_time"; }; then
            state="pending"
        else
            state=$(splunk_s3_input_state "$input_file")
        fi

        case "$state" in
        ready)
            return 0
            ;;
        failed)
            echo "Splunk S3 data source provisioning failed: $(jq -c '.dataSourcesStatus' "$input_file")" >>"$log_file"
            return 1
            ;;
        esac

        if [ "$attempt" -eq "$max_attempts" ]; then
            echo "Splunk S3 data source was not ready after $max_attempts attempts." >>"$log_file"
            return 1
        fi

        sleep "$poll_interval_seconds"
        attempt=$((attempt + 1))
        needs_fetch=true
    done
}

splunk_validate_cloudformation_template() {
    jq -e '(.Resources | type) == "object" and (.Resources | length) > 0' "$1" >/dev/null 2>&1
}
