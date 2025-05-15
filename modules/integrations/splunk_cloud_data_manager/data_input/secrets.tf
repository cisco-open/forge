locals {
  secrets = {
    splunk_cloud_username = {
      name = "/app/tf/splunk_cloud_username"
    }
    splunk_cloud_password = {
      name = "/app/tf/splunk_cloud_password"
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
