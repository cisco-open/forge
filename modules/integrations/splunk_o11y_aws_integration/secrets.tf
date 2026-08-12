locals {
  splunk_ingest_token_region = coalesce(var.splunk_ingest_token_region, var.aws_region)

  secrets = {
    splunk_o11y_ingest_token_aws_integration = {
      name = "/cicd/common/splunk_o11y_ingest_token_aws_integration"
    }
  }
}

data "aws_secretsmanager_secret" "secrets" {
  for_each = local.secrets
  name     = each.value.name
  region   = local.splunk_ingest_token_region
}

data "aws_secretsmanager_secret_version" "secrets" {
  for_each  = data.aws_secretsmanager_secret.secrets
  secret_id = each.value.id
  region    = local.splunk_ingest_token_region
}
