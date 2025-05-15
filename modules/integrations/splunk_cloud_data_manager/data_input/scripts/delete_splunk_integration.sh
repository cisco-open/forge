#!/bin/bash

# shellcheck disable=all

# Variables
splunk_cloud="${1}"
splunk_input_uuid="${2}"
splunk_cloud_username="${3}"
splunk_cloud_password="${4}"

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

# Check delete readiness
echo -e "\n\n\n-----------\n\Checking delete readiness...\n\n" >>/tmp/${splunk_input_uuid}_logs.txt
DATA_RAW=$(cat /tmp/${splunk_input_uuid}_input.json | jq -c '.mode = "ReadyForDelete" | del(._key, ._user, .createTime, .id, .lastUpdateTime, .schemaVersion, .details.stackName, .details.version, .details.resources, .details.resourceTags)')
curl "${splunk_cloud}/en-GB/splunkd/__raw/servicesNS/nobody/data_manager/cloudinput/inputs/${splunk_input_uuid}/validate/checkdeletereadiness" \
    -X 'GET' \
    -H 'Accept: application/json, text/plain, */*' \
    -H 'Content-Type: application/json' \
    -b "splunkweb_csrf_token_8443=$SPLUNKWEB_CSRF_TOKEN_8443; splunk_csrf_token=$SPLUNKWEB_CSRF_TOKEN_8443; splunkd_8443=$SPLUNKD_8443; AWSELB=$AWSELB" \
    -H 'Sec-Fetch-Dest: empty' \
    -H 'Sec-Fetch-Mode: cors' \
    -H 'Sec-Fetch-Site: same-origin' \
    -H 'X-Requested-With: XMLHttpRequest' \
    -H "X-Splunk-Form-Key: $SPLUNKWEB_CSRF_TOKEN_8443" >>/tmp/${splunk_input_uuid}_logs.txt 2>&1

# Update the input to "MarkedForDelete"
echo -e "\n\n\n-----------\n\nUpdating the input to 'MarkedForDelete'...\n\n" >>/tmp/${splunk_input_uuid}_logs.txt
DATA_RAW=$(cat /tmp/${splunk_input_uuid}_input.json | jq -c '.mode = "MarkedForDelete" | del(._key, ._user, .createTime, .id, .lastUpdateTime, .schemaVersion, .details.stackName, .details.version, .details.resources, .details.resourceTags)')
curl "${splunk_cloud}/en-GB/splunkd/__raw/servicesNS/nobody/data_manager/cloudinput/inputs/${splunk_input_uuid}" \
    -X 'PUT' \
    -H 'Accept: application/json, text/plain, */*' \
    -H 'Content-Type: application/json' \
    -b "splunkweb_csrf_token_8443=$SPLUNKWEB_CSRF_TOKEN_8443; splunk_csrf_token=$SPLUNKWEB_CSRF_TOKEN_8443; splunkd_8443=$SPLUNKD_8443; AWSELB=$AWSELB" \
    -H 'Sec-Fetch-Dest: empty' \
    -H 'Sec-Fetch-Mode: cors' \
    -H 'Sec-Fetch-Site: same-origin' \
    -H 'X-Requested-With: XMLHttpRequest' \
    -H "X-Splunk-Form-Key: $SPLUNKWEB_CSRF_TOKEN_8443" \
    --data-raw "$DATA_RAW" >>/tmp/${splunk_input_uuid}_logs.txt 2>&1

# Check delete readiness
echo -e "\n\n\n-----------\n\Checking delete readiness...\n\n" >>/tmp/${splunk_input_uuid}_logs.txt
DATA_RAW=$(cat /tmp/${splunk_input_uuid}_input.json | jq -c '.mode = "ReadyForDelete" | del(._key, ._user, .createTime, .id, .lastUpdateTime, .schemaVersion, .details.stackName, .details.version, .details.resources, .details.resourceTags)')
curl "${splunk_cloud}/en-GB/splunkd/__raw/servicesNS/nobody/data_manager/cloudinput/inputs/${splunk_input_uuid}/validate/checkdeletereadiness" \
    -X 'GET' \
    -H 'Accept: application/json, text/plain, */*' \
    -H 'Content-Type: application/json' \
    -b "splunkweb_csrf_token_8443=$SPLUNKWEB_CSRF_TOKEN_8443; splunk_csrf_token=$SPLUNKWEB_CSRF_TOKEN_8443; splunkd_8443=$SPLUNKD_8443; AWSELB=$AWSELB" \
    -H 'Sec-Fetch-Dest: empty' \
    -H 'Sec-Fetch-Mode: cors' \
    -H 'Sec-Fetch-Site: same-origin' \
    -H 'X-Requested-With: XMLHttpRequest' \
    -H "X-Splunk-Form-Key: $SPLUNKWEB_CSRF_TOKEN_8443" >>/tmp/${splunk_input_uuid}_logs.txt 2>&1

# Delete the input for each dataset key
DATASETS=("aws-cwl" "cwl-custom-logs" "cwl-vpc-flow-logs" "cloudtrail" "securityhub" "guardduty" "iam-aa" "iam-cr" "metadata")
for DATASET in "${DATASETS[@]}"; do
    echo -e "\n\n\n-----------\n\nDeleting the input for dataset $DATASET...\n\n" >>/tmp/${splunk_input_uuid}_logs.txt
    curl "${splunk_cloud}/en-US/splunkd/__raw/servicesNS/nobody/data_manager/cloudinput/inputs/${splunk_input_uuid}/hectoken?dataset=$DATASET" \
        -X 'DELETE' \
        -H 'Accept: application/json, text/plain, */*' \
        -H 'Content-Type: text/plain' \
        -b "splunkweb_csrf_token_8443=$SPLUNKWEB_CSRF_TOKEN_8443; splunk_csrf_token=$SPLUNKWEB_CSRF_TOKEN_8443; splunkd_8443=$SPLUNKD_8443; AWSELB=$AWSELB" \
        -H 'Sec-Fetch-Dest: empty' \
        -H 'Sec-Fetch-Mode: cors' \
        -H 'Sec-Fetch-Site: same-origin' \
        -H 'X-Requested-With: XMLHttpRequest' \
        -H "X-Splunk-Form-Key: $SPLUNKWEB_CSRF_TOKEN_8443" >>/tmp/${splunk_input_uuid}_logs.txt 2>&1
done

# Check delete readiness
echo -e "\n\n\n-----------\n\Checking delete readiness...\n\n" >>/tmp/${splunk_input_uuid}_logs.txt
DATA_RAW=$(cat /tmp/${splunk_input_uuid}_input.json | jq -c '.mode = "ReadyForDelete" | del(._key, ._user, .createTime, .id, .lastUpdateTime, .schemaVersion, .details.stackName, .details.version, .details.resources, .details.resourceTags)')
curl "${splunk_cloud}/en-GB/splunkd/__raw/servicesNS/nobody/data_manager/cloudinput/inputs/${splunk_input_uuid}/validate/checkdeletereadiness" \
    -X 'GET' \
    -H 'Accept: application/json, text/plain, */*' \
    -H 'Content-Type: application/json' \
    -b "splunkweb_csrf_token_8443=$SPLUNKWEB_CSRF_TOKEN_8443; splunk_csrf_token=$SPLUNKWEB_CSRF_TOKEN_8443; splunkd_8443=$SPLUNKD_8443; AWSELB=$AWSELB" \
    -H 'Sec-Fetch-Dest: empty' \
    -H 'Sec-Fetch-Mode: cors' \
    -H 'Sec-Fetch-Site: same-origin' \
    -H 'X-Requested-With: XMLHttpRequest' \
    -H "X-Splunk-Form-Key: $SPLUNKWEB_CSRF_TOKEN_8443" >>/tmp/${splunk_input_uuid}_logs.txt 2>&1

# Delete the input
echo -e "\n\n\n-----------\n\nDeleting the input...\n\n" >>/tmp/${splunk_input_uuid}_logs.txt
curl "${splunk_cloud}/en-US/splunkd/__raw/servicesNS/nobody/data_manager/cloudinput/inputs/${splunk_input_uuid}" \
    -X 'DELETE' \
    -H 'Accept: application/json, text/plain, */*' \
    -H 'Content-Type: text/plain' \
    -b "splunkweb_csrf_token_8443=$SPLUNKWEB_CSRF_TOKEN_8443; splunk_csrf_token=$SPLUNKWEB_CSRF_TOKEN_8443; splunkd_8443=$SPLUNKD_8443; AWSELB=$AWSELB" \
    -H 'Sec-Fetch-Dest: empty' \
    -H 'Sec-Fetch-Mode: cors' \
    -H 'Sec-Fetch-Site: same-origin' \
    -H 'X-Requested-With: XMLHttpRequest' \
    -H "X-Splunk-Form-Key: $SPLUNKWEB_CSRF_TOKEN_8443" >>/tmp/${splunk_input_uuid}_logs.txt 2>&1
