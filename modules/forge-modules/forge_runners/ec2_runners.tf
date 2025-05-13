
# For generating a webhook secret. Apparently this is a cryptographically secure
# PRNG.
resource "random_id" "random" {
  byte_length = 20
}

module "ec2_runners" {
  # Using multi-runner example as a baseline.
  source = "../ec2_runners"

  aws_region = var.aws_region

  network_configs = {
    vpc_id            = var.vpc_id
    subnet_ids        = var.subnet_ids
    lambda_subnet_ids = var.lambda_subnet_ids
  }

  tenant_configs = {
    ecr_registries = var.tenant.ecr_registries
    tags           = local.all_security_tags
  }

  runner_configs = {
    prefix                              = local.runner_prefix
    ghes_url                            = var.ghes_url
    ghes_org                            = var.ghes_org
    log_level                           = var.log_level
    runner_iam_role_managed_policy_arns = local.runner_iam_role_managed_policy_arns
    github_app = {
      key_base64     = data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_key"].secret_string
      id             = data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_id"].secret_string
      webhook_secret = random_id.random.hex
    }
    runner_group_name = var.runner_group_name
    runner_specs      = var.ec2_runner_specs
  }
}
