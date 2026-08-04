locals {
  splunk_cloud_username = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_username"].secret_string
  splunk_cloud_password = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_password"].secret_string
}

data "external" "splunk_data" {
  program = [
    "python3",
    "${path.module}/scripts/splunk_data_manager.py",
    "authenticate",
  ]

  query = {
    splunk_cloud = var.splunk_cloud
    username     = local.splunk_cloud_username
    password     = local.splunk_cloud_password
  }
}

data "external" "config" {
  program = [
    "python3",
    "${path.module}/scripts/splunk_data_manager.py",
    "config",
  ]

  query = {
    splunk_cloud              = var.splunk_cloud
    splunkweb_csrf_token_8443 = data.external.splunk_data.result["splunkweb_csrf_token_8443"]
    splunkd_8443              = data.external.splunk_data.result["splunkd_8443"]
    awselb                    = data.external.splunk_data.result["awselb"]
  }

  depends_on = [data.external.splunk_data]
}
