locals {
  cicd_secrets_prefix = "/cicd/common/${var.deployment_config.tenant.name}/${var.deployment_config.secret_suffix}/"

  secrets = [
    # CI/CD runners: secrets used in build/deploy pipelines.
    {
      name          = "${local.cicd_secrets_prefix}github_actions_runners_app_key"
      description   = "Base64 encoded GitHub App private key for GHA ephemeral runners for Tenant ${var.deployment_config.tenant.name}(${var.deployment_config.secret_suffix})."
      recovery_days = 7
    },
    {
      name          = "${local.cicd_secrets_prefix}github_actions_runners_app_id"
      description   = "GitHub App ID for GHA ephemeral runners for Tenant ${var.deployment_config.tenant.name}(${var.deployment_config.secret_suffix})."
      recovery_days = 7
    },
    {
      name          = "${local.cicd_secrets_prefix}github_actions_runners_app_client_id"
      description   = "GitHub App Client ID for GHA ephemeral runners for Tenant ${var.deployment_config.tenant.name}(${var.deployment_config.secret_suffix})."
      recovery_days = 7
    },
    {
      name          = "${local.cicd_secrets_prefix}github_actions_runners_app_installation_id"
      description   = "GitHub App Installation ID for GHA ephemeral runners for Tenant ${var.deployment_config.tenant.name}(${var.deployment_config.secret_suffix})."
      recovery_days = 7
    },
    {
      name          = "${local.cicd_secrets_prefix}github_actions_runners_app_name"
      description   = "GitHub App Name for GHA ephemeral runners for Tenant ${var.deployment_config.tenant.name}(${var.deployment_config.secret_suffix})."
      recovery_days = 7
    }
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

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

# Force a delay between secret creation and seeding. We only need a few
# seconds, but if we don't do this, we get into a bad state requiring manual
# intervention and/or manual forced-deletion of secrets.
resource "time_sleep" "wait_60_seconds" {
  depends_on = [
    aws_secretsmanager_secret.cicd_secrets,
  ]
  create_duration = "60s"
}

# Only used for seeding purposes. Will not clobber/overwrite secrets afterward
# (i.e. if/when we set them manually via the AWS CLI or management console).
resource "aws_secretsmanager_secret_version" "cicd_secrets" {
  depends_on = [time_sleep.wait_60_seconds]
  for_each = {
    for key, val in local.secrets : val.name => val
  }

  secret_id     = aws_secretsmanager_secret.cicd_secrets[each.key].id
  secret_string = base64encode(data.aws_secretsmanager_random_password.secret_seeds[each.key].random_password)

  # Prevents this seed from being applied more than once (at initial "tf apply"
  # time).
  lifecycle {
    ignore_changes = [secret_string, ]
  }
}

# Critical secrets needed for provisioning the CICD system.
data "aws_secretsmanager_secret" "data_cicd_secrets" {
  for_each = {
    for key, val in local.secrets : val.name => val
  }

  depends_on = [
    aws_secretsmanager_secret.cicd_secrets,
  ]
  arn = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${each.key}"
}

# Need both these objects to be able to extract the secrets' respective
# payloads.
data "aws_secretsmanager_secret_version" "data_cicd_secrets" {
  for_each = {
    for key, val in local.secrets : val.name => val
  }

  depends_on = [
    aws_secretsmanager_secret_version.cicd_secrets,
    data.aws_secretsmanager_secret.data_cicd_secrets
  ]
  secret_id = data.aws_secretsmanager_secret.data_cicd_secrets[each.key].id
}
