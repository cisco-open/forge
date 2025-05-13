# Re-use AWS settings from root module.
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  # Required, as per security guidelines.
  default_tags {
    tags = var.default_tags
  }
}

provider "splunk" {
  url                  = "${var.splunk_conf.splunk_cloud}:8089"
  auth_token           = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_api_token"].secret_string
  insecure_skip_verify = true
}
