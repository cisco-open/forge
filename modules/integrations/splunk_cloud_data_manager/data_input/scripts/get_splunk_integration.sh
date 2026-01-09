#!/bin/bash

# shellcheck disable=all

# Variables
splunk_cloud="${1}"
splunk_input_uuid="${2}"
splunk_cloud_username="${3}"
splunk_cloud_password="${4}"
splunk_cloud_input_json="${5}"

# Perform the login and save cookies
echo -e "\n\n\n-----------\n\nPerforming initial login to Splunk Cloud and saving cookies...\n\n" >>/tmp/${splunk_input_uuid}_logs.txt
splunk_cloud_url="${splunk_cloud}/en-US/account/login?loginType=splunk"
curl -c /tmp/${splunk_input_uuid}_cookies.txt "$splunk_cloud_url" >>/tmp/${splunk_input_uuid}_logs.txt 2>&1

# Extract the required values
SPLUNKWEB_UID=$(grep splunkweb_uid /tmp/${splunk_input_uuid}_cookies.txt | awk '{print $7}')
CVAL=$(grep cval /tmp/${splunk_input_uuid}_cookies.txt | awk '{print $7}')

# Perform the second login and save cookies
echo -e "\n\n\n-----------\n\nPerforming second login to Splunk Cloud and saving cookies...\n\n" >>/tmp/${splunk_input_uuid}_logs.txt
curl "${splunk_cloud}/en-GB/account/login" \
    -b "cval=$CVAL; splunkweb_uid=$SPLUNKWEB_UID" \
    -c /tmp/${splunk_input_uuid}_cookies2.txt \
    -H 'Sec-Fetch-Dest: empty' \
    -H 'Sec-Fetch-Mode: cors' \
    -H 'Sec-Fetch-Site: same-origin' \
    -H 'X-Requested-With: XMLHttpRequest' \
    --data-raw "cval=$CVAL&username=${splunk_cloud_username}&password=${splunk_cloud_password}" >>/tmp/${splunk_input_uuid}_logs.txt 2>&1

SPLUNKWEB_CSRF_TOKEN_8443=$(grep splunkweb_csrf_token_8443 /tmp/${splunk_input_uuid}_cookies2.txt | awk '{print $7}')
SPLUNKD_8443=$(grep splunkd_8443 /tmp/${splunk_input_uuid}_cookies2.txt | awk '{print $7}')
AWSELB=$(grep AWSELB /tmp/${splunk_input_uuid}_cookies2.txt | awk '{print $7}')

# Fetch the input JSON
echo -e "\n\n\n-----------\n\nFetching the input JSON from Splunk Cloud...\n\n" >>/tmp/${splunk_input_uuid}_logs.txt
curl "${splunk_cloud}/en-GB/splunkd/__raw/servicesNS/nobody/data_manager/cloudinput/inputs/${splunk_input_uuid}" \
    -X 'GET' \
    -H 'Accept: application/json, text/plain, */*' \
    -H 'Content-Type: text/plain' \
    -b "splunkweb_csrf_token_8443=$SPLUNKWEB_CSRF_TOKEN_8443; splunk_csrf_token=$SPLUNKWEB_CSRF_TOKEN_8443; splunkd_8443=$SPLUNKD_8443; AWSELB=$AWSELB" \
    -H 'Sec-Fetch-Dest: empty' \
    -H 'Sec-Fetch-Mode: cors' \
    -H 'Sec-Fetch-Site: same-origin' \
    -H 'X-Requested-With: XMLHttpRequest' \
    -H "X-Splunk-Form-Key: $SPLUNKWEB_CSRF_TOKEN_8443" -o /tmp/${splunk_input_uuid}_input.json >>/tmp/${splunk_input_uuid}_logs.txt 2>&1

# Get hectoken for each dataset key
DATASET_KEYS=$(cat /tmp/${splunk_input_uuid}_input.json | jq -r '.details.datasetInfo | keys[]')
for DATASET in $DATASET_KEYS; do
    case "$DATASET" in
    cwl-api-gateway | cwl-cloudhsm | cwl-documentDB | cwl-eks | cwl-lambda | cwl-rds)
        CATEGORY="aws-cwl"
        ;;
    cwl-custom-logs)
        CATEGORY="cwl-custom-logs"
        ;;
    cwl-vpc-flow-logs)
        CATEGORY="cwl-vpc-flow-logs"
        ;;
    cloudtrail)
        CATEGORY="cloudtrail"
        ;;
    securityhub)
        CATEGORY="securityhub"
        ;;
    guardduty)
        CATEGORY="guardduty"
        ;;
    iam-aa)
        CATEGORY="iam-aa"
        ;;
    iam-cr)
        CATEGORY="iam-cr"
        ;;
    metadata)
        CATEGORY="metadata"
        ;;
    esac

    while true; do
        echo -e "\n\n\n-----------\n\nFetching hectoken for dataset $CATEGORY...\n\n" >>/tmp/${splunk_input_uuid}_logs.txt
        curl "${splunk_cloud}/en-US/splunkd/__raw/servicesNS/nobody/data_manager/cloudinput/inputs/${splunk_input_uuid}/hectoken?dataset=$CATEGORY" \
            -X 'GET' \
            -H 'Accept: application/json, text/plain, */*' \
            -H 'Content-Type: application/json' \
            -b "splunkweb_csrf_token_8443=$SPLUNKWEB_CSRF_TOKEN_8443; splunk_csrf_token=$SPLUNKWEB_CSRF_TOKEN_8443; splunkd_8443=$SPLUNKD_8443; AWSELB=$AWSELB" \
            -H 'Sec-Fetch-Dest: empty' \
            -H 'Sec-Fetch-Mode: cors' \
            -H 'Sec-Fetch-Site: same-origin' \
            -H 'X-Requested-With: XMLHttpRequest' \
            -H "X-Splunk-Form-Key: $SPLUNKWEB_CSRF_TOKEN_8443" -o /tmp/${splunk_input_uuid}_${CATEGORY}_hectoken.json >>/tmp/${splunk_input_uuid}_logs.txt 2>&1

        if jq -e '.details == "Noah stack token creation in progress"' /tmp/${splunk_input_uuid}_${CATEGORY}_hectoken.json >/dev/null; then
            echo "Noah stack token creation in progress for dataset $CATEGORY. Run again after 1 minute." >>/tmp/${splunk_input_uuid}_logs.txt
            sleep 60
        elif jq -e '.token != null and .token != ""' /tmp/${splunk_input_uuid}_${CATEGORY}_hectoken.json >/dev/null; then
            echo "Token exists and is not empty for dataset $CATEGORY." >>/tmp/${splunk_input_uuid}_logs.txt
            break
        else
            echo "Unexpected response for dataset $CATEGORY. Check logs for details." >>/tmp/${splunk_input_uuid}_logs.txt
            break
        fi
    done
done

# Fetch Template
echo -e "\n\n\n-----------\n\nFetching the CloudFormation template from Splunk Cloud...\n\n" >>/tmp/${splunk_input_uuid}_logs.txt
curl "${splunk_cloud}/en-GB/splunkd/__raw/servicesNS/nobody/data_manager/cloudinput/inputs/${splunk_input_uuid}/templates/dataaccount/ingest" \
    -H 'Accept: application/json, text/plain, */*' \
    -H 'Content-Type: text/plain' \
    -b "splunkweb_csrf_token_8443=$SPLUNKWEB_CSRF_TOKEN_8443; splunk_csrf_token=$SPLUNKWEB_CSRF_TOKEN_8443; splunkd_8443=$SPLUNKD_8443; AWSELB=$AWSELB" \
    -H 'Sec-Fetch-Dest: empty' \
    -H 'Sec-Fetch-Mode: cors' \
    -H 'Sec-Fetch-Site: same-origin' \
    -H 'X-Requested-With: XMLHttpRequest' \
    -H "X-Splunk-Form-Key: $SPLUNKWEB_CSRF_TOKEN_8443" \
    -o /tmp/${splunk_input_uuid}_template.json >>/tmp/${splunk_input_uuid}_logs.txt 2>&1

# Calculate the hash of the template
TEMPLATE_HASH=$(shasum -a 256 /tmp/${splunk_input_uuid}_template.json | awk '{print $1}')

# Output the version and template hash
cat /tmp/${splunk_input_uuid}_input.json | jq -c --arg hash "$TEMPLATE_HASH" '{version: .details.version, template_hash: $hash}'
