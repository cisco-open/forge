mock_provider "signalfx" {
  mock_resource "signalfx_list_chart" {
    defaults = {
      id = "list-chart-id"
    }
  }
  mock_resource "signalfx_time_chart" {
    defaults = {
      id = "time-chart-id"
    }
  }
  mock_resource "signalfx_dashboard" {}
}

variables {
  dashboard_group = "forge-dashboard-group"
  tenant_names    = ["tenant-b", "tenant-a"]
  dynamic_variables = [{
    property               = "AWSRegion"
    alias                  = "AWS region"
    description            = "Regional dependency probe scope."
    values                 = ["eu-west-1"]
    value_required         = true
    values_suggested       = ["eu-west-1"]
    restricted_suggestions = true
  }]
}

run "creates_dependency_health_dashboard" {
  command = plan

  assert {
    condition     = signalfx_dashboard.dependency_health.name == "Forge External Dependency Health"
    error_message = "The dependency-health dashboard must keep its operator-facing name."
  }

  assert {
    condition     = length(signalfx_dashboard.dependency_health.chart) == 5
    error_message = "The dashboard must retain GitHub, AWS, rate-limit, latency, and telemetry coverage."
  }

  assert {
    condition     = signalfx_dashboard.dependency_health.variable[0].values_suggested == toset(["tenant-a", "tenant-b"])
    error_message = "The dashboard tenant selector must use the configured tenant names."
  }

  assert {
    condition = (
      length(signalfx_dashboard.dependency_health.variable) == 2
      && signalfx_dashboard.dependency_health.variable[1].property == "AWSRegion"
      && signalfx_dashboard.dependency_health.variable[1].values == toset(["eu-west-1"])
    )
    error_message = "The dependency dashboard must render its own configured dynamic variables."
  }

  assert {
    condition = (
      strcontains(signalfx_list_chart.github_availability.program_text, "forge.dependency.availability")
      && !strcontains(signalfx_list_chart.github_availability.program_text, "filter('namespace'")
      && strcontains(signalfx_list_chart.github_availability.program_text, "filter('TenantName', 'tenant-a')")
      && strcontains(signalfx_list_chart.github_availability.program_text, "filter('TenantName', 'tenant-b')")
    )
    error_message = "Dependency charts must use direct Splunk metric names and remain scoped to configured tenants."
  }
}
