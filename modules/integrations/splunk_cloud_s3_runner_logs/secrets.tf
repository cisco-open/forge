locals {
  secrets = {
    splunk_cloud_hec_token_s3_integration = {
      name = "/cicd/common/splunk_cloud_hec_token_s3_integration"
    }
  }
}

data "aws_secretsmanager_secret" "secrets" {
  for_each = local.secrets
  name     = each.value.name
}

data "aws_secretsmanager_secret_version" "secrets" {
  for_each  = data.aws_secretsmanager_secret.secrets
  secret_id = each.value.id
}
