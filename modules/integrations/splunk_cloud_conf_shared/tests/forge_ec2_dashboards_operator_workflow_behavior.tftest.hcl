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

run "orders_ec2_failure_dashboards_for_operator_triage" {
  command = plan

  assert {
    condition = alltrue([
      for body in [
        splunk_data_ui_views.forge_ec2_fleet_scale_up_failures.eai_data,
        splunk_data_ui_views.forge_ec2_run_instances_scale_up_failures.eai_data,
        splunk_data_ui_views.forge_ec2_runner_lifecycle.eai_data,
      ] :
      strcontains(body, "How should I use this dashboard?")
      && strcontains(body, "Healthy:")
      && strcontains(body, "Action:")
      && strcontains(body, "\"description\": \"Answers")
    ])
    error_message = "Every EC2 dashboard must provide operator guidance and panel-level measurement, healthy-state, and next-action descriptions."
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_ec2_fleet_scale_up_failures.eai_data, "source=\\\"*:/aws/lambda/*scale-up:*\\\"")
      && strcontains(splunk_data_ui_views.forge_ec2_run_instances_scale_up_failures.eai_data, "source=\\\"*:/aws/lambda/*scale-up:*\\\"")
      && strcontains(splunk_data_ui_views.forge_ec2_fleet_scale_up_failures.eai_data, "| search forgecicd_log_type=\\\"scale-up\\\"")
      && strcontains(splunk_data_ui_views.forge_ec2_run_instances_scale_up_failures.eai_data, "| search forgecicd_log_type=\\\"scale-up\\\"")
    )
    error_message = "Scale-up failure searches must apply indexed sourcetype and Lambda-source constraints before search-time fields."
  }

  assert {
    condition = (
      can(regex("\"item\": \"operator_guide\"[\\s\\S]*\"item\": \"tenant_error_summary_table\"[\\s\\S]*\"item\": \"fleet_error_trend_chart\"[\\s\\S]*\"item\": \"request_drilldown_table\"", splunk_data_ui_views.forge_ec2_fleet_scale_up_failures.eai_data))
      && can(regex("\"item\": \"operator_guide\"[\\s\\S]*\"item\": \"run_instances_summary_table\"[\\s\\S]*\"item\": \"run_instances_error_trend_chart\"[\\s\\S]*\"item\": \"run_instances_drilldown_table\"", splunk_data_ui_views.forge_ec2_run_instances_scale_up_failures.eai_data))
    )
    error_message = "EC2 failure dashboards must place scope and actionable failures before trends and request drilldowns."
  }
}
