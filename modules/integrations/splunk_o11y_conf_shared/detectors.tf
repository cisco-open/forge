locals {
  detector_notifications = var.detector_notifications == null ? ["Team,${var.team}"] : var.detector_notifications
}

module "detector_k8s" {
  source = "./detectors/k8s"

  providers = {
    signalfx = signalfx
  }

  detector_notifications    = local.detector_notifications
  detector_name_prefix      = var.detector_name_prefix
  dynamic_variables         = var.dashboard_variables.runner_k8s.dynamic_variables
  k8s_detector_config       = var.k8s_detector_config
  k8s_otel_collector_config = var.k8s_otel_collector_config
  k8s_platform_namespaces   = var.k8s_platform_namespaces
  team                      = var.team
  tenant_names              = var.dashboard_variables.runner_k8s.tenant_names
}

module "detector_dependency_probes" {
  count  = var.dependency_probe_detector_config.enabled ? 1 : 0
  source = "./detectors/dependency_probes"

  providers = {
    signalfx = signalfx
  }

  detector_config = {
    failure_duration                   = var.dependency_probe_detector_config.failure_duration
    no_data_duration                   = var.dependency_probe_detector_config.no_data_duration
    no_data_fill_duration              = var.dependency_probe_detector_config.no_data_fill_duration
    rate_limit_duration                = var.dependency_probe_detector_config.rate_limit_duration
    rate_limit_remaining_pct_threshold = var.dependency_probe_detector_config.rate_limit_remaining_pct_threshold
  }
  detector_name_prefix = var.detector_name_prefix
  detector_notifications = (
    local.detector_notifications
  )
  team         = var.team
  tenant_names = var.dashboard_variables.dependency_probes.tenant_names
}
