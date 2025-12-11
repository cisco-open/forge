module "github_global_lock" {
  source = "./github_global_lock"

  providers = {
    aws = aws
  }

  prefix = var.deployment_config.deployment_prefix
  github_app = {
    key_base64_ssm = {
      arn  = aws_ssm_parameter.github_app_key.arn
      name = aws_ssm_parameter.github_app_key.name
    }
    id_ssm = {
      arn  = aws_ssm_parameter.github_app_id.arn
      name = aws_ssm_parameter.github_app_id.name
    }
    installation_id_ssm = {
      arn  = aws_ssm_parameter.github_app_installation_id.arn
      name = aws_ssm_parameter.github_app_installation_id.name
    }
  }
  logging_retention_in_days = var.logging_retention_in_days
  log_level                 = var.log_level
  tags                      = local.all_security_tags

}
