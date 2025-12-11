
# For generating a webhook secret. Apparently this is a cryptographically secure
# PRNG.
resource "random_id" "random" {
  count       = length(var.ec2_deployment_specs.runner_specs) > 0 ? 1 : 0
  byte_length = 20
}

module "ec2_runners" {
  count = length(var.ec2_deployment_specs.runner_specs) > 0 ? 1 : 0
  # Using multi-runner example as a baseline.
  source = "../ec2_deployment"

  aws_region = var.aws_region

  providers = {
    aws = aws
  }

  network_configs = {
    vpc_id            = var.ec2_deployment_specs.vpc_id
    subnet_ids        = var.ec2_deployment_specs.subnet_ids
    lambda_subnet_ids = var.ec2_deployment_specs.lambda_subnet_ids
  }

  tenant_configs = {
    ecr_registries = var.deployment_config.tenant.ecr_registries
    tags           = local.all_security_tags
  }

  runner_configs = {
    env                                 = var.deployment_config.env
    prefix                              = var.deployment_config.deployment_prefix
    ghes_url                            = var.deployment_config.github.ghes_url
    ghes_org                            = var.deployment_config.github.ghes_org
    log_level                           = var.log_level
    logging_retention_in_days           = var.logging_retention_in_days
    runner_iam_role_managed_policy_arns = local.runner_iam_role_managed_policy_arns
    github_app = {
      key_base64     = data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_key"].secret_string
      id             = data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_id"].secret_string
      webhook_secret = random_id.random[0].hex
    }
    runner_group_name = var.deployment_config.github.runner_group_name
    runner_specs      = var.ec2_deployment_specs.runner_specs
  }
}
