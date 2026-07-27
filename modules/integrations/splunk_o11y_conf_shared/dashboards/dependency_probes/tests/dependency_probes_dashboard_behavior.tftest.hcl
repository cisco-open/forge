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
  detector_ids = {
    tenant-a = "tenant-a-detector-id"
    tenant-b = "tenant-b-detector-id"
  }
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
    condition     = length(signalfx_dashboard.dependency_health.chart) == 6
    error_message = "The dashboard must retain GitHub, AWS, rate-limit, latency, telemetry, and central alert coverage."
  }

  assert {
    condition = (
      signalfx_dashboard.dependency_health.variable[0].property == "aws_tag_TenantName"
      && signalfx_dashboard.dependency_health.variable[0].alias == "ForgeCICD Tenant Name"
      && length(signalfx_dashboard.dependency_health.variable[0].values) == 0
      && signalfx_dashboard.dependency_health.variable[0].values_suggested == toset(["tenant-a", "tenant-b"])
    )
    error_message = "The dashboard tenant selector must use the Forge AWS tag convention and suggest the configured tenant names without selecting them by default."
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

  assert {
    condition = (
      alltrue([
        for program_text in [
          signalfx_list_chart.github_availability.program_text,
          signalfx_list_chart.ssm_availability.program_text,
          signalfx_list_chart.rate_limit_budget.program_text,
          signalfx_time_chart.probe_execution.program_text,
        ] :
        !strcontains(program_text, "alerts(detector_id=")
      ])
      && !strcontains(signalfx_time_chart.latency.program_text, "alerts(detector_id=")
      && strcontains(signalfx_time_chart.tenant_health_alerts.program_text, "alerts(detector_id='tenant-a-detector-id')")
      && strcontains(signalfx_time_chart.tenant_health_alerts.program_text, "alerts(detector_id='tenant-b-detector-id')")
      && signalfx_time_chart.tenant_health_alerts.show_event_lines
    )
    error_message = "Dependency metric charts must remain alert-free and expose tenant alerts only on the central timeline."
  }
}
