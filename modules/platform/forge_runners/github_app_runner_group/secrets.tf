locals {
  secrets = {
    github_actions_runners_app_key = {
      name = "${var.secrets_prefix}github_actions_runners_app_key"
    }
    github_actions_runners_app_id = {
      name = "${var.secrets_prefix}github_actions_runners_app_id"
    }
    github_actions_runners_app_installation_id = {
      name = "${var.secrets_prefix}github_actions_runners_app_installation_id"
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
