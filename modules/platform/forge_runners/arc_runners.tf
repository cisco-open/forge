

module "arc_runners" {
  # Using multi-runner example as a baseline.
  source = "../arc_deployment"

  aws_profile = var.aws_profile
  aws_region  = var.aws_region

  tenant_configs = {
    ecr_registries = var.tenant.ecr_registries
    name           = var.tenant.name
    tags           = local.all_security_tags
  }

  runner_configs = {
    arc_cluster_name                    = var.arc_cluster_name
    migrate_arc_cluster                 = var.migrate_arc_cluster
    prefix                              = var.deployment_config.prefix
    ghes_url                            = var.ghes_url
    ghes_org                            = var.ghes_org
    log_level                           = var.log_level
    runner_iam_role_managed_policy_arns = local.runner_iam_role_managed_policy_arns
    github_app = {
      key_base64      = data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_key"].secret_string
      id              = data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_id"].secret_string
      installation_id = data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_installation_id"].secret_string
    }
    runner_group_name = var.runner_group_name
    runner_specs      = var.arc_runner_specs
  }
}
