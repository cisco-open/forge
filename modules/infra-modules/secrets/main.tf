locals {
  cicd_secrets_prefix = "/cicd/common"
  app_tf_prefix       = "/app/tf"

  secrets = [

    {
      name          = "${local.cicd_secrets_prefix}/github_repo_access"
      description   = "GitHub personal access token (PAT) for pulling repos from GitHub Cloud."
      recovery_days = 7
    },
    {
      name          = "${local.cicd_secrets_prefix}/github_private_ssh_key"
      description   = "GitHub private SSH key used for pushing and signing commits in GitHub Cloud."
      recovery_days = 7
    },
    {
      name          = "${local.app_tf_prefix}/splunk_access_ingest_token"
      description   = "Splunk Observability Cloud Access Token for Ingest"
      recovery_days = 7
    },
    {
      name          = "${local.app_tf_prefix}/splunk_access_api_token"
      description   = "Splunk Observability Cloud Access Token for API"
      recovery_days = 7
    },
    {
      name          = "${local.app_tf_prefix}/splunk_o11y_username"
      description   = "Splunk o11y Username"
      recovery_days = 7
    },
    {
      name          = "${local.app_tf_prefix}/splunk_o11y_password"
      description   = "Splunk o11y Password"
      recovery_days = 7
    },
    {
      name          = "${local.app_tf_prefix}/splunk_cloud_username"
      description   = "Splunk Cloud Username"
      recovery_days = 7
    },
    {
      name          = "${local.app_tf_prefix}/splunk_cloud_password"
      description   = "Splunk Cloud Password"
      recovery_days = 7
    },
    {
      name          = "${local.app_tf_prefix}/splunk_cloud_api_token"
      description   = "Splunk Cloud API token"
      recovery_days = 7
    },
    {
      name          = "${local.app_tf_prefix}/splunk_cloud_hec_token_eks"
      description   = "Splunk Cloud HEC token for eks"
      recovery_days = 7
    },
  ]
}

# Psuedo-random seeds we use for initializing the secrets. If we don't do this,
# then the secret "exists", but has no value or initial version, and "tf apply"
# steps fail, requiring one to manually set the password outside of Terraform.
data "aws_secretsmanager_random_password" "secret_seeds" {
  for_each = {
    for key, val in local.secrets : val.name => val
  }

  password_length = 16
}

# Actual object containing the secret.
resource "aws_secretsmanager_secret" "cicd_secrets" {
  for_each = {
    for key, val in local.secrets : val.name => val
  }

  name                    = each.value.name
  description             = each.value.description
  recovery_window_in_days = each.value.recovery_days
  tags                    = local.all_security_tags
  tags_all                = local.all_security_tags

}

# Force a delay between secret creation and seeding. We only need a few
# seconds, but if we don't do this, we get into a bad state requiring manual
# intervention and/or manual forced-deletion of secrets.
resource "time_sleep" "wait_30_seconds" {
  depends_on = [
    aws_secretsmanager_secret.cicd_secrets,
  ]
  create_duration = "30s"
}

# Only used for seeding purposes. Will not clobber/overwrite secrets afterward
# (i.e. if/when we set them manually via the AWS CLI or management console).
resource "aws_secretsmanager_secret_version" "cicd_secrets" {
  depends_on = [time_sleep.wait_30_seconds]
  for_each = {
    for key, val in local.secrets : val.name => val
  }

  secret_id     = aws_secretsmanager_secret.cicd_secrets[each.key].id
  secret_string = data.aws_secretsmanager_random_password.secret_seeds[each.key].random_password

  # Prevents this seed from being applied more than once (at initial "tf apply"
  # time).
  lifecycle {
    ignore_changes = [secret_string, ]
  }
}
