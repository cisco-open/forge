provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  # Required, as per security guidelines.
  default_tags {
    tags = merge(var.default_tags, )
  }
}

provider "signalfx" {
  api_url = var.splunk_api_url

  email           = data.aws_secretsmanager_secret_version.secrets["splunk_o11y_username"].secret_string
  password        = data.aws_secretsmanager_secret_version.secrets["splunk_o11y_password"].secret_string
  organization_id = var.splunk_organization_id
}
