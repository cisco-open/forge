locals {
  secrets = {
    splunk_o11y_username = {
      name = "/cicd/common/splunk_o11y_username"
    }
    splunk_o11y_password = {
      name = "/cicd/common/splunk_o11y_password"
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
