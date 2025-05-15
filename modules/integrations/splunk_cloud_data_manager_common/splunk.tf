locals {
  splunk_cloud_username = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_username"].secret_string
  splunk_cloud_password = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_password"].secret_string
}

data "external" "splunk_data" {
  program = [
    "bash", "-c",
    <<-EOF
      splunk_cloud_url="${var.splunk_cloud}/en-US/account/login?loginType=splunk"

      # Perform the login and save cookies
      curl -c /tmp/cookies.txt "$splunk_cloud_url" > /dev/null 2>&1

      # Extract the required values
      splunkweb_uid=$(grep splunkweb_uid cookies.txt | awk '{print $7}')
      cval=$(grep cval /tmp/cookies.txt | awk '{print $7}')

      # Perform the second login and save cookies
      curl '${var.splunk_cloud}/en-GB/account/login' \
        -b "cval=$cval; splunkweb_uid=$splunkweb_uid" \
        -c /tmp/cookies2.txt \
        -H 'Sec-Fetch-Dest: empty' \
        -H 'Sec-Fetch-Mode: cors' \
        -H 'Sec-Fetch-Site: same-origin' \
        -H 'X-Requested-With: XMLHttpRequest' \
        --data-raw "cval=$cval&username=${local.splunk_cloud_username}&password=${local.splunk_cloud_password}" > /dev/null 2>&1

      splunkweb_csrf_token_8443=$(grep splunkweb_csrf_token_8443 /tmp/cookies2.txt | awk '{print $7}')
      splunkd_8443=$(grep splunkd_8443 /tmp/cookies2.txt | awk '{print $7}')
      awselb=$(grep AWSELB /tmp/cookies2.txt | awk '{print $7}')

      # Output the values in JSON format
      jq -n --arg splunkweb_uid "$splunkweb_uid" --arg cval "$cval" --arg splunkweb_csrf_token_8443 "$splunkweb_csrf_token_8443" --arg splunkd_8443 "$splunkd_8443" --arg awselb "$awselb" '{"splunkweb_uid": $splunkweb_uid, "cval": $cval, "splunkweb_csrf_token_8443": $splunkweb_csrf_token_8443, "splunkd_8443": $splunkd_8443, "awselb": $awselb}'
    EOF
  ]
}

data "external" "config" {
  program = [
    "bash", "-c",
    <<-EOF
      curl '${var.splunk_cloud}/en-US/splunkd/__raw/servicesNS/nobody/data_manager/cloudinput/globalconfig' \
        -H 'Accept: application/json, text/plain, */*' \
        -b "splunkweb_csrf_token_8443=${data.external.splunk_data.result["splunkweb_csrf_token_8443"]}; splunk_csrf_token=${data.external.splunk_data.result["splunkweb_csrf_token_8443"]}; splunkd_8443=${data.external.splunk_data.result["splunkd_8443"]}; AWSELB=${data.external.splunk_data.result["awselb"]}" \
        -H 'Sec-Fetch-Dest: empty' \
        -H 'Sec-Fetch-Mode: cors' \
        -H 'Sec-Fetch-Site: same-origin' \
        -H 'X-Requested-With: XMLHttpRequest' \
        -H "X-Splunk-Form-Key: ${data.external.splunk_data.result["splunkweb_csrf_token_8443"]}" \
        -o /tmp/config.json > /dev/null 2>&1
      cat /tmp/config.json | jq '.aws'
    EOF
  ]
  depends_on = [data.external.splunk_data]
}
