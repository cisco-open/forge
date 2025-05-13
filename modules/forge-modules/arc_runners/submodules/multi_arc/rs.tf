module "rs" {
  source   = "./submodules/gha_runner_scale_set"
  for_each = coalesce(var.multi_runner_config, {})

  # EKS Cluster Configuration
  cluster_name = data.aws_eks_cluster.cluster.id

  # Helm Chart Configuration
  release_name  = each.value.runner_set_configs.release_name
  namespace     = each.value.runner_set_configs.namespace
  chart_name    = each.value.runner_set_configs.chart_name
  chart_version = each.value.runner_set_configs.chart_version

  # GitHub Configuration
  ghes_org          = var.ghes_org
  ghes_url          = var.ghes_url
  runner_group_name = var.runner_group_name

  # Runner Configuration
  container_actions_runner  = each.value.runner_config.container_actions_runner
  container_limits_cpu      = each.value.runner_config.container_limits_cpu
  container_limits_memory   = each.value.runner_config.container_limits_memory
  container_requests_cpu    = each.value.runner_config.container_requests_cpu
  container_requests_memory = each.value.runner_config.container_requests_memory
  container_ecr_registries  = each.value.runner_config.container_ecr_registries
  scale_set_name            = each.value.runner_config.scale_set_name
  scale_set_type            = each.value.runner_config.scale_set_type
  service_account           = each.value.runner_config.prefix
  secret_name               = var.controller_config.release_name
  runner_size               = each.value.runner_config.runner_size
  controller = {
    service_account = each.value.runner_config.controller.service_account
    namespace       = each.value.runner_config.controller.namespace
  }

  # IAM Role Policies
  iam_role_name                       = "${each.value.runner_config.prefix}-arc-runner-role"
  runner_iam_role_managed_policy_arns = each.value.runner_config.runner_iam_role_managed_policy_arns

  depends_on = [module.rsc]

  tags = var.tags
}
