resource "signalfx_dashboard_group" "forgecicd" {
  name        = var.dashboard_group_name
  description = ""
  teams       = [var.team]

  lifecycle {
    ignore_changes = [
      import_qualifier
    ]
  }
}

# Core platform health
module "dashboard_runner_ec2" {
  source = "./dashboards/runner_ec2"

  providers = {
    signalfx = signalfx
  }

  tenant_names      = var.dashboard_variables.runner_ec2.tenant_names
  dynamic_variables = var.dashboard_variables.runner_ec2.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
  detector_ids      = module.detector_ec2_runner_health.detector_ids
}

module "dashboard_runner_k8s" {
  source = "./dashboards/runner_k8s"

  providers = {
    signalfx = signalfx
  }

  tenant_names      = var.dashboard_variables.runner_k8s.tenant_names
  dynamic_variables = var.dashboard_variables.runner_k8s.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
  detector_ids = {
    otel_no_data        = module.detector_k8s.detector_ids.otel_no_data
    tenant_pods_pending = module.detector_k8s.detector_ids.tenant_pods_pending
  }
}

module "dashboard_arc_runner_operations" {
  source = "./dashboards/arc_runner_operations"

  providers = {
    signalfx = signalfx
  }

  tenant_names      = var.dashboard_variables.arc_runner_operations.tenant_names
  dynamic_variables = var.dashboard_variables.arc_runner_operations.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
}

module "dashboard_k8s_control_plane" {
  source = "./dashboards/k8s_control_plane"

  providers = {
    signalfx = signalfx
  }

  dynamic_variables   = var.dashboard_variables.runner_k8s.dynamic_variables
  platform_namespaces = var.k8s_platform_namespaces
  dashboard_group     = signalfx_dashboard_group.forgecicd.id
  detector_ids = {
    otel_collector_health   = module.detector_k8s.detector_ids.otel_collector_health
    platform_pods_unhealthy = module.detector_k8s.detector_ids.platform_pods_unhealthy
  }
}

module "dashboard_lambda" {
  source = "./dashboards/lambda"

  providers = {
    signalfx = signalfx
  }

  tenant_names            = var.dashboard_variables.lambda.tenant_names
  dynamic_variables       = var.dashboard_variables.lambda.dynamic_variables
  dashboard_group         = signalfx_dashboard_group.forgecicd.id
  lambda_dimension_filter = local.lambda_dimension_filter
}

module "dashboard_lambda_control_plane" {
  source = "./dashboards/lambda_control_plane"

  providers = {
    signalfx = signalfx
  }

  dynamic_variables       = var.dashboard_variables.lambda_control_plane.dynamic_variables
  dashboard_group         = signalfx_dashboard_group.forgecicd.id
  detector_id             = module.detector_aws_regional_health.lambda_control_plane_detector_id
  lambda_dimension_filter = local.lambda_dimension_filter
}

module "dashboard_kinesis_control_plane" {
  source = "./dashboards/kinesis_control_plane"

  providers = {
    signalfx = signalfx
  }

  dynamic_variables = var.dashboard_variables.kinesis_control_plane.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
}

module "dashboard_runner_logs_ingestion" {
  source = "./dashboards/runner_logs_ingestion"

  providers = {
    signalfx = signalfx
  }

  dynamic_variables       = var.dashboard_variables.runner_logs_ingestion.dynamic_variables
  dashboard_group         = signalfx_dashboard_group.forgecicd.id
  detector_id             = module.detector_aws_regional_health.runner_log_delivery_detector_id
  lambda_dimension_filter = local.lambda_dimension_filter
}

module "dashboard_dependency_probes" {
  source = "./dashboards/dependency_probes"

  providers = {
    signalfx = signalfx
  }

  tenant_names      = var.dashboard_variables.dependency_probes.tenant_names
  dynamic_variables = var.dashboard_variables.dependency_probes.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
  detector_ids      = module.detector_dependency_probes.detector_ids
}

module "dashboard_aws_regional_health" {
  source = "./dashboards/aws_regional_health"

  providers = {
    signalfx = signalfx
  }

  dynamic_variables       = var.dashboard_variables.aws_regional_health.dynamic_variables
  dashboard_group         = signalfx_dashboard_group.forgecicd.id
  detector_id             = module.detector_aws_regional_health.detector_id
  lambda_dimension_filter = local.lambda_dimension_filter
}

# Messaging and storage
module "dashboard_sqs" {
  source = "./dashboards/sqs"

  providers = {
    signalfx = signalfx
  }

  tenant_names      = var.dashboard_variables.sqs.tenant_names
  dynamic_variables = var.dashboard_variables.sqs.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
}

module "dashboard_sqs_control_plane" {
  source = "./dashboards/sqs_control_plane"

  providers = {
    signalfx = signalfx
  }

  dynamic_variables = var.dashboard_variables.sqs_control_plane.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
  detector_id       = module.detector_aws_regional_health.sqs_control_plane_detector_id
}

module "dashboard_s3" {
  source = "./dashboards/s3"

  providers = {
    signalfx = signalfx
  }

  tenant_names      = var.dashboard_variables.s3.tenant_names
  dynamic_variables = var.dashboard_variables.s3.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
}

module "dashboard_s3_control_plane" {
  source = "./dashboards/s3_control_plane"

  providers = {
    signalfx = signalfx
  }

  dynamic_variables = var.dashboard_variables.s3_control_plane.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
}

module "dashboard_dynamodb" {
  source = "./dashboards/dynamodb"

  providers = {
    signalfx = signalfx
  }

  tenant_names      = var.dashboard_variables.dynamodb.tenant_names
  dynamic_variables = var.dashboard_variables.dynamodb.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
}

module "dashboard_ebs" {
  source = "./dashboards/ebs"

  providers = {
    signalfx = signalfx
  }

  tenant_names      = var.dashboard_variables.ebs.tenant_names
  dynamic_variables = var.dashboard_variables.ebs.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
}

module "dashboard_forge_impact" {
  source = "./dashboards/forge_impact"

  providers = {
    signalfx = signalfx
  }

  tenant_names            = var.dashboard_variables.forge_impact.tenant_names
  dynamic_variables       = var.dashboard_variables.forge_impact.dynamic_variables
  dashboard_group         = signalfx_dashboard_group.forgecicd.id
  detector_ids            = module.detector_dependency_probes.detector_ids
  lambda_dimension_filter = local.lambda_dimension_filter
}

module "dashboard_runner_usage" {
  source = "./dashboards/runner_usage"

  providers = {
    signalfx = signalfx
  }

  tenant_names      = try(var.dashboard_variables.forge_impact.tenant_names, var.dashboard_variables.runner_k8s.tenant_names)
  dynamic_variables = try(var.dashboard_variables.forge_impact.dynamic_variables, [])
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
}

# Cost and usage
module "dashboard_opencost" {
  source = "./dashboards/opencost"

  providers = {
    signalfx = signalfx
  }

  tenant_names      = var.dashboard_variables.runner_k8s.tenant_names
  dynamic_variables = var.dashboard_variables.runner_k8s.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
}

module "dashboard_billing" {
  source = "./dashboards/billing"

  providers = {
    signalfx = signalfx
  }

  tenant_names      = var.dashboard_variables.billing.tenant_names
  dynamic_variables = var.dashboard_variables.billing.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
}

module "dashboard_aws_service_limits" {
  source = "./dashboards/aws_service_limits"

  providers = {
    signalfx = signalfx
  }

  dynamic_variables = var.dashboard_variables.aws_service_limits.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
}
