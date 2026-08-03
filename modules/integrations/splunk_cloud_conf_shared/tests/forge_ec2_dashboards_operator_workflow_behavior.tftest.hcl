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
      !strcontains(body, "\"operator_guide\"")
      && !strcontains(body, "\"type\": \"splunk.markdown\"")
      && strcontains(body, "\"description\": \"Answers")
    ])
    error_message = "EC2 dashboards must keep operational guidance in compact panel descriptions."
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
      can(regex("\"item\": \"tenant_error_summary_table\"[\\s\\S]*\"item\": \"fleet_error_trend_chart\"[\\s\\S]*\"item\": \"request_drilldown_table\"", splunk_data_ui_views.forge_ec2_fleet_scale_up_failures.eai_data))
      && can(regex("\"item\": \"run_instances_summary_table\"[\\s\\S]*\"item\": \"run_instances_error_trend_chart\"[\\s\\S]*\"item\": \"run_instances_drilldown_table\"", splunk_data_ui_views.forge_ec2_run_instances_scale_up_failures.eai_data))
    )
    error_message = "EC2 failure dashboards must place scope and actionable failures before trends and request drilldowns."
  }

  assert {
    condition = (
      can(jsondecode(local.forge_ec2_run_instances_scale_up_failures_definition))
      && strcontains(splunk_data_ui_views.forge_ec2_run_instances_scale_up_failures.eai_data, "RunInstances request failed for dedicated host.")
      && strcontains(splunk_data_ui_views.forge_ec2_run_instances_scale_up_failures.eai_data, "RunInstances did not create every requested instance.")
      && strcontains(splunk_data_ui_views.forge_ec2_run_instances_scale_up_failures.eai_data, "SQS messages will be retried.")
      && strcontains(splunk_data_ui_views.forge_ec2_run_instances_scale_up_failures.eai_data, "messageIds{}")
      && strcontains(splunk_data_ui_views.forge_ec2_run_instances_scale_up_failures.eai_data, "nonRetryableErrorCount")
    )
    error_message = "RunInstances searches must use only the v7.10.1 failure and retry log contract."
  }
}
