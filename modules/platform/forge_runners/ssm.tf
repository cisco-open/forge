resource "aws_ssm_parameter" "github_app_key" {
  name        = "/forge/${var.deployment_config.deployment_prefix}/github_app_key"
  description = "Base64 encoded GitHub App private key for GHA ephemeral runners for Tenant ${var.deployment_config.tenant.name}."
  type        = "SecureString"
  value       = base64encode("initial-placeholder-value")
  tags        = local.all_security_tags

  lifecycle {
    # Allow operators to rotate the key directly in SSM without Terraform
    # forcing it back to the original value.
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "github_app_id" {
  name        = "/forge/${var.deployment_config.deployment_prefix}/github_app_id"
  description = "GitHub App ID for GHA ephemeral runners for Tenant ${var.deployment_config.tenant.name}."
  type        = "SecureString"
  value       = var.deployment_config.github_app.id

  tags = local.all_security_tags
}

resource "aws_ssm_parameter" "github_app_client_id" {
  name        = "/forge/${var.deployment_config.deployment_prefix}/github_app_client_id"
  description = "GitHub App Client ID for GHA ephemeral runners for Tenant ${var.deployment_config.tenant.name}."
  type        = "SecureString"
  value       = var.deployment_config.github_app.client_id

  tags = local.all_security_tags
}

resource "aws_ssm_parameter" "github_app_installation_id" {
  name        = "/forge/${var.deployment_config.deployment_prefix}/github_app_installation_id"
  description = "GitHub App Installation ID for GHA ephemeral runners for Tenant ${var.deployment_config.tenant.name}."
  type        = "SecureString"
  value       = var.deployment_config.github_app.installation_id

  tags = local.all_security_tags
}

resource "aws_ssm_parameter" "github_app_name" {
  name        = "/forge/${var.deployment_config.deployment_prefix}/github_app_name"
  description = "GitHub App Name for GHA ephemeral runners for Tenant ${var.deployment_config.tenant.name}."
  type        = "SecureString"
  value       = var.deployment_config.github_app.name

  tags = local.all_security_tags
}

resource "aws_ssm_parameter" "github_app_webhook_secret" {
  name        = "/forge/${var.deployment_config.deployment_prefix}/github_app_webhook_secret"
  description = "GitHub App webhook secret for GHA ephemeral runners for Tenant ${var.deployment_config.tenant.name}."
  type        = "SecureString"
  value       = random_password.github_app_webhook_secret.result

  tags = local.all_security_tags
}


resource "time_rotating" "every_30_days" {
  rotation_days = 30
}

resource "random_password" "github_app_webhook_secret" {
  length = 20

  keepers = {
    rotation = time_rotating.every_30_days.id
  }
}

data "aws_ssm_parameter" "github_app_key" {
  name            = aws_ssm_parameter.github_app_key.name
  with_decryption = true
  depends_on      = [aws_ssm_parameter.github_app_key]
}
