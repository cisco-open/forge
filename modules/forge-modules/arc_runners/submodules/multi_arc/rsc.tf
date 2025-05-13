module "rsc" {
  count  = length(var.multi_runner_config) > 0 ? 1 : 0
  source = "./submodules/gha_runner_scale_set_controller"

  # Helm Chart Configuration
  release_name  = var.controller_config.release_name
  namespace     = var.controller_config.namespace
  chart_name    = var.controller_config.chart_name
  chart_version = var.controller_config.chart_version

  controller_config = {
    name = var.controller_config.name
  }

  github_app = var.github_app
}
