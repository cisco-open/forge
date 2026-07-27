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
  tenant_pods_pending_notifications = (
    length(setsubtract(
      toset(var.dashboard_variables.runner_k8s.tenant_names),
      toset(var.dashboard_variables.dependency_probes.tenant_names),
    )) == 0 ? [] : local.detector_notifications
  )
}

module "detector_dependency_probes" {
  source = "./detectors/dependency_probes"

  providers = {
    signalfx = signalfx
  }

  detector_config = {
    failure_duration                   = "10m"
    no_data_duration                   = "15m"
    no_data_fill_duration              = "4h"
    rate_limit_duration                = "10m"
    rate_limit_remaining_pct_threshold = 10
  }
  detector_name_prefix = var.detector_name_prefix
  detector_notifications = (
    local.detector_notifications
  )
  team         = var.team
  tenant_names = var.dashboard_variables.dependency_probes.tenant_names
}

module "detector_aws_regional_health" {
  source = "./detectors/aws_regional_health"

  providers = {
    signalfx = signalfx
  }

  detector_name_prefix = var.detector_name_prefix
  detector_notifications = (
    local.detector_notifications
  )
  dynamic_variables = var.dashboard_variables.aws_regional_health.dynamic_variables
  team              = var.team
}

module "detector_ec2_runner_health" {
  source = "./detectors/ec2_runner_health"

  providers = {
    signalfx = signalfx
  }

  detector_name_prefix   = var.detector_name_prefix
  detector_notifications = local.detector_notifications
  dynamic_variables      = var.dashboard_variables.runner_ec2.dynamic_variables
  team                   = var.team
  tenant_names           = var.dashboard_variables.runner_ec2.tenant_names
  resource_pressure_notifications = (
    length(setsubtract(
      toset(var.dashboard_variables.runner_ec2.tenant_names),
      toset(var.dashboard_variables.dependency_probes.tenant_names),
    )) == 0 ? [] : local.detector_notifications
  )
}
