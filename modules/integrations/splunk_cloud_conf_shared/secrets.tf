locals {
  ro_secrets = {
    splunk_cloud_api_token = {
      name = "/cicd/common/splunk_cloud_api_token"
    }
  }
}

data "aws_secretsmanager_secret" "secrets" {
  for_each = local.ro_secrets
  name     = each.value.name
}

data "aws_secretsmanager_secret_version" "secrets" {
  for_each  = data.aws_secretsmanager_secret.secrets
  secret_id = each.value.id
}
