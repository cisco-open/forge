locals {
  secrets = {
    dockerhub_user = {
      name = "/cicd/common/dockerhub_user"
    }
    dockerhub_token = {
      name = "/cicd/common/dockerhub_token"
    }
    dockerhub_email = {
      name = "/cicd/common/dockerhub_email"
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
