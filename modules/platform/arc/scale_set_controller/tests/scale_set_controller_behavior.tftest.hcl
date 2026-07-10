mock_provider "kubernetes" {}
mock_provider "helm" {}

variables {
  chart_name    = "gha-runner-scale-set-controller"
  chart_version = "0.12.1"
  namespace     = "arc-system"
  release_name  = "arc-controller"
  controller_config = {
    name = "arc-controller"
  }
  github_app = {
    key_base64      = base64encode("private-key")
    id              = "12345"
    installation_id = "67890"
  }
  migrate_arc_cluster = false
  log_level           = "DEBUG"
}

run "scale_set_controller_contract" {
  command = plan

  assert {
    condition = (
      kubernetes_namespace_v1.controller_namespace[0].metadata[0].name == "arc-system"
      && kubernetes_secret_v1.github_app[0].metadata[0].name == "arc-controller"
      && kubernetes_secret_v1.github_app[0].metadata[0].namespace == "arc-system"
      && kubernetes_secret_v1.github_app[0].type == "generic"
      && kubernetes_secret_v1.github_app[0].data.github_app_id == "12345"
      && kubernetes_secret_v1.github_app[0].data.github_app_installation_id == "67890"
      && kubernetes_secret_v1.github_app[0].data.github_app_private_key == "private-key"
    )
    error_message = "ARC controller must keep namespace and GitHub App secret wiring from inputs."
  }

  assert {
    condition = (
      helm_release.gha_runner_scale_set_controller[0].name == "arc-controller"
      && helm_release.gha_runner_scale_set_controller[0].namespace == "arc-system"
      && helm_release.gha_runner_scale_set_controller[0].chart == "gha-runner-scale-set-controller"
      && helm_release.gha_runner_scale_set_controller[0].version == "0.12.1"
      && helm_release.gha_runner_scale_set_controller[0].create_namespace == true
      && helm_release.gha_runner_scale_set_controller[0].force_update == true
      && helm_release.gha_runner_scale_set_controller[0].cleanup_on_fail == true
      && helm_release.gha_runner_scale_set_controller[0].timeout == 1200
      && strcontains(helm_release.gha_runner_scale_set_controller[0].values[0], "debug")
    )
    error_message = "ARC controller Helm release must keep chart inputs, safety flags, timeout, and lower-case log level values."
  }
}

run "scale_set_controller_migration_contract" {
  command = plan

  variables {
    migrate_arc_cluster = true
  }

  assert {
    condition = (
      length(kubernetes_namespace_v1.controller_namespace) == 0
      && length(kubernetes_secret_v1.github_app) == 0
      && length(helm_release.gha_runner_scale_set_controller) == 0
    )
    error_message = "ARC controller migration mode must suppress namespace, GitHub App secret, and Helm release creation."
  }
}
