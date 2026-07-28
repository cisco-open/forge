mock_provider "aws" {
  mock_data "aws_secretsmanager_secret" {
    defaults = { id = "/cicd/common/splunk-cloud" }
  }
  mock_data "aws_secretsmanager_secret_version" {
    defaults = { secret_string = "mock" }
  }
}

mock_provider "splunk" {
  mock_resource "splunk_data_ui_views" {}
  mock_resource "splunk_configs_conf" {}
  mock_resource "splunk_transforms_regex" {}
}

variables {
  aws_profile  = "test"
  aws_region   = "us-east-1"
  default_tags = { Product = "Forge" }
  splunk_conf = {
    splunk_cloud = "https://example.splunkcloud.com"
    index        = "srea-forge-prod-index"
    tenant_names = ["tenant-a"]
    acl = {
      app = "search", owner = "nobody", sharing = "app", read = ["*"], write = ["admin"]
    }
  }
}

run "orders_control_plane_dashboards_for_operator_triage" {
  command = plan

  assert {
    condition = alltrue([
      for body in [
        splunk_data_ui_views.forge_runner_capacity.eai_data,
        splunk_data_ui_views.forge_runner_control_plane_health.eai_data,
        splunk_data_ui_views.forge_trust_failures.eai_data,
      ] :
      !strcontains(body, "\"operator_guide\"")
      && !strcontains(body, "\"type\": \"splunk.markdown\"")
      && strcontains(body, "\"description\": \"Answers")
    ])
    error_message = "Capacity, control-plane, and trust dashboards must keep guidance in compact panel descriptions."
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_runner_capacity.eai_data, "One elevated percentile is not enough to infer failure")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "Global-lock cleanup is diagnostic and is not causal evidence for a stuck job")
      && strcontains(splunk_data_ui_views.forge_trust_failures.eai_data, "TagSession")
    )
    error_message = "Control-plane guidance must prevent single-chart failure inference, false global-lock causality, and incomplete STS trust triage."
  }

  assert {
    condition = (
      can(regex("\"item\": \"queue_pressure_table\"[\\s\\S]*\"item\": \"queue_trend_chart\"", splunk_data_ui_views.forge_runner_capacity.eai_data))
      && can(regex("\"item\": \"assume_role_failures_table\"[\\s\\S]*\"item\": \"trust_failure_trend_chart\"[\\s\\S]*\"item\": \"latest_validation_table\"", splunk_data_ui_views.forge_trust_failures.eai_data))
    )
    error_message = "Capacity and trust dashboards must place actionable failures before trend and investigation detail."
  }
}
