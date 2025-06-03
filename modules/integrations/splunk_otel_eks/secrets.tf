locals {
  secrets = {
    splunk_access_ingest_token = {
      name = "/cicd/common/splunk_access_ingest_token"
    }
    splunk_cloud_hec_token_eks = {
      name = "/cicd/common/splunk_cloud_hec_token_eks"
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
