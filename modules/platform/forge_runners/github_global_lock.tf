module "github_global_lock" {
  source = "./github_global_lock"

  providers = {
    aws = aws
  }

  prefix = var.deployment_config.deployment_prefix
  github_app = {
    key_base64_ssm = {
      arn = aws_ssm_parameter.github_app_key.arn
    }
    id_ssm = {
      arn = aws_ssm_parameter.github_app_id.arn
    }
    installation_id_ssm = {
      arn = aws_ssm_parameter.github_app_installation_id.arn
    }
  }
  logging_retention_in_days = var.logging_retention_in_days
  log_level                 = var.log_level
  tags                      = local.all_security_tags

  depends_on = [data.aws_secretsmanager_secret_version.data_cicd_secrets]
}
