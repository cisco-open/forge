locals {
  splunk_secrets = {
    splunk_cloud_hec_token_dependency_monitor = {
      name = "/cicd/common/splunk_cloud_hec_token_dependency_monitor"
    }
    splunk_o11y_ingest_token_dependency_monitor = {
      name = "/cicd/common/splunk_o11y_ingest_token_dependency_monitor"
    }
  }
}

data "aws_secretsmanager_secret" "secrets" {
  for_each = local.splunk_secrets
  name     = each.value.name
}

data "aws_secretsmanager_secret_version" "secrets" {
  for_each  = data.aws_secretsmanager_secret.secrets
  secret_id = each.value.id
}
