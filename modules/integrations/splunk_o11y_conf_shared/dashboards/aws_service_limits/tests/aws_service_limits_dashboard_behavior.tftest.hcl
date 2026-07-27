mock_provider "signalfx" {
  mock_resource "signalfx_list_chart" {
    defaults = { id = "list-chart-id" }
  }
  mock_resource "signalfx_dashboard" {}
}

variables {
  dashboard_group = "forge-dashboard-group"
  dynamic_variables = [
    {
      property               = "aws_account_id"
      alias                  = "AWS account"
      description            = ""
      values                 = []
      value_required         = false
      values_suggested       = ["111111111111"]
      restricted_suggestions = true
    },
    {
      property               = "Region"
      alias                  = "AWS region"
      description            = ""
      values                 = []
      value_required         = false
      values_suggested       = ["eu-west-1", "us-west-2"]
      restricted_suggestions = true
    },
  ]
}

run "creates_aws_service_limits_dashboard" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.aws_service_limits.name == "Forge Control Plane - AWS Service Limits"
      && length(signalfx_dashboard.aws_service_limits.chart) == 8
      && length(signalfx_dashboard.aws_service_limits.variable) == 2
      && length(signalfx_list_chart.service_limit) == 8
    )
    error_message = "The AWS service-limits dashboard must create one chart for each supported Forge AWS service."
  }

  assert {
    condition = alltrue([
      for chart in values(signalfx_list_chart.service_limit) :
      strcontains(chart.program_text, "filter('aws_account_id', '111111111111')")
      && strcontains(chart.program_text, "filter('Region', '-')")
      && strcontains(chart.program_text, "filter('Region', 'eu-west-1')")
      && strcontains(chart.program_text, "filter('namespace', 'AWS/TrustedAdvisor')")
      && strcontains(chart.program_text, "filter('stat', 'upper')")
      && strcontains(chart.program_text, "data('ServiceLimitUsage'")
      && strcontains(chart.program_text, ".mean(over='7d').scale(100)")
      && strcontains(chart.program_text, ".max(by=['Region', 'ServiceLimit'])")
      && chart.color_by == "Scale"
      && anytrue([for scale in chart.color_scale : scale.gte == 80 && scale.lt == 100])
      && anytrue([for scale in chart.color_scale : scale.gte == 100])
    ])
    error_message = "Every service-limit chart must preserve the built-in Trusted Advisor percentage calculation and warning/critical thresholds."
  }

  assert {
    condition = toset([
      for chart in values(signalfx_list_chart.service_limit) :
      regex("filter\\('ServiceName', '([^']+)'\\)", chart.program_text)[0]
      ]) == toset([
      "AutoScaling",
      "CloudFormation",
      "DynamoDB",
      "EBS",
      "EC2",
      "IAM",
      "Route53",
      "VPC",
    ])
    error_message = "The dashboard must have one chart for every Trusted Advisor service used by Forge."
  }
}
