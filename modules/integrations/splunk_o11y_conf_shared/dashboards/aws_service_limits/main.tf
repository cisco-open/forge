locals {
  aws_account_ids = distinct(flatten([
    for var_def in var.dynamic_variables : var_def.values_suggested
    if var_def.property == "aws_account_id"
  ]))
  aws_regions = distinct(flatten([
    for var_def in var.dynamic_variables : var_def.values_suggested
    if var_def.property == "Region"
  ]))

  aws_account_filter = length(local.aws_account_ids) > 0 ? join(" or ", [
    for account_id in sort(local.aws_account_ids) : "filter('aws_account_id', '${account_id}')"
  ]) : "filter('aws_account_id', '__forge_aws_account_scope_not_configured__')"
  aws_region_filter = length(local.aws_regions) > 0 ? join(" or ", concat(
    ["filter('Region', '-')"],
    [for aws_region in sort(local.aws_regions) : "filter('Region', '${aws_region}')"],
  )) : "filter('Region', '__forge_aws_region_scope_not_configured__')"

  aws_service_limit_filter = "(${local.aws_account_filter}) and (${local.aws_region_filter}) and filter('namespace', 'AWS/TrustedAdvisor') and filter('stat', 'upper')"

  forge_services = {
    autoscaling = {
      column       = 6
      display_name = "Auto Scaling"
      row          = 1
      service_name = "AutoScaling"
    }
    cloudformation = {
      column       = 0
      display_name = "CloudFormation"
      row          = 3
      service_name = "CloudFormation"
    }
    dynamodb = {
      column       = 0
      display_name = "DynamoDB"
      row          = 2
      service_name = "DynamoDB"
    }
    ebs = {
      column       = 6
      display_name = "EBS"
      row          = 0
      service_name = "EBS"
    }
    ec2 = {
      column       = 0
      display_name = "EC2"
      row          = 0
      service_name = "EC2"
    }
    iam = {
      column       = 6
      display_name = "IAM"
      row          = 2
      service_name = "IAM"
    }
    route53 = {
      column       = 6
      display_name = "Route 53"
      row          = 3
      service_name = "Route53"
    }
    vpc = {
      column       = 0
      display_name = "VPC"
      row          = 1
      service_name = "VPC"
    }
  }
}

resource "signalfx_list_chart" "service_limit" {
  for_each = local.forge_services

  name        = "${each.value.display_name} service-limit usage"
  description = "One-day average AWS Trusted Advisor service-limit usage for ${each.value.display_name}, by region and limit."

  program_text = "A = data('ServiceLimitUsage', filter=(${local.aws_service_limit_filter}) and filter('ServiceName', '${each.value.service_name}'), rollup='average').mean(over='1d').scale(100).max(by=['Region', 'ServiceLimit']).publish(label='A')"
  sort_by      = "-value"

  color_by                = "Scale"
  disable_sampling        = true
  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"
  time_range              = 86400

  color_scale {
    color = "green"
    lt    = 80
  }
  color_scale {
    color = "orange"
    gte   = 80
    lt    = 100
  }
  color_scale {
    color = "red"
    gte   = 100
  }

  legend_options_fields {
    enabled  = true
    property = "Region"
  }
  legend_options_fields {
    enabled  = true
    property = "ServiceLimit"
  }

  viz_options {
    display_name = "${each.value.display_name} limit usage"
    label        = "A"
    value_suffix = "%"
  }
}

resource "terraform_data" "dashboard_parent" {
  triggers_replace = var.dashboard_group
}

resource "signalfx_dashboard" "aws_service_limits" {
  name            = "Forge Control Plane - AWS Service Limits"
  description     = "AWS Trusted Advisor service-limit usage for AWS services used by Forge."
  dashboard_group = var.dashboard_group
  time_range      = "-24h"

  lifecycle {
    replace_triggered_by = [
      terraform_data.dashboard_parent,
    ]
  }

  dynamic "variable" {
    for_each = var.dynamic_variables
    iterator = var_def

    content {
      property               = var_def.value.property
      alias                  = var_def.value.alias
      description            = var_def.value.description
      values                 = var_def.value.values
      value_required         = var_def.value.value_required
      values_suggested       = var_def.value.values_suggested
      restricted_suggestions = var_def.value.restricted_suggestions
    }
  }

  dynamic "chart" {
    for_each = local.forge_services
    iterator = service

    content {
      chart_id = signalfx_list_chart.service_limit[service.key].id
      row      = service.value.row
      column   = service.value.column
      width    = 6
      height   = 1
    }
  }
}
