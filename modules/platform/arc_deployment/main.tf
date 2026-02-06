

module "arc" {
  source = "../../core/arc"

  aws_profile = var.aws_profile
  aws_region  = var.aws_region

  ghes_org = var.runner_configs.ghes_org
  ghes_url = var.runner_configs.ghes_url

  runner_group_name = var.runner_configs.runner_group_name

  eks_cluster_name = var.runner_configs.arc_cluster_name

  tags = var.tenant_configs.tags

  multi_runner_config = {
    for key, val in coalesce(var.runner_configs.runner_specs, {}) :
    key => {
      runner_set_configs = {
        release_name  = "${var.runner_configs.prefix}-${key}"
        namespace     = var.tenant_configs.name
        chart_name    = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set"
        chart_version = "0.13.1"
      }
      runner_config = {
        runner_size                         = val.runner_size
        prefix                              = "${var.runner_configs.prefix}-${key}"
        scale_set_name                      = val.scale_set_name
        scale_set_type                      = val.scale_set_type
        container_actions_runner            = val.container_actions_runner
        container_limits_cpu                = val.container_limits_cpu
        container_limits_memory             = val.container_limits_memory
        container_requests_cpu              = val.container_requests_cpu
        container_requests_memory           = val.container_requests_memory
        volume_requests_storage_type        = val.volume_requests_storage_type
        volume_requests_storage_size        = val.volume_requests_storage_size
        container_ecr_registries            = var.tenant_configs.ecr_registries
        runner_iam_role_managed_policy_arns = var.runner_configs.runner_iam_role_managed_policy_arns
        controller = {
          service_account = "${var.runner_configs.prefix}-gha-rs-controller"
          namespace       = var.tenant_configs.name
        }
      }
    }

  }
  controller_config = {
    release_name  = var.runner_configs.prefix
    namespace     = var.tenant_configs.name
    chart_name    = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller"
    chart_version = "0.13.1"
    name          = "${var.runner_configs.prefix}-gha-rs-controller"
  }

  github_app = var.runner_configs.github_app

  migrate_arc_cluster = var.runner_configs.migrate_arc_cluster
}
