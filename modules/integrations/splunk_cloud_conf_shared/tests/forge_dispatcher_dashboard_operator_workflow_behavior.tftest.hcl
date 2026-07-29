mock_provider "aws" {
  mock_data "aws_secretsmanager_secret" {
    defaults = {
      id = "/cicd/common/splunk-cloud"
    }
  }

  mock_data "aws_secretsmanager_secret_version" {
    defaults = {
      secret_string = "mock-splunk-secret"
    }
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
    acl = {
      app     = "search_app_srea"
      owner   = "nobody"
      sharing = "app"
      read    = ["*"]
      write   = ["admin"]
    }
    index        = "srea-forge-prod-index"
    tenant_names = ["tenant-a"]
  }
  stuck_workflow_job_dispatcher_name_prefix = "forge-dispatcher"
}

run "orders_dispatcher_dashboards_for_operator_triage" {
  command = plan

  assert {
    condition = (
      can(regex(
        "\"item\": \"dispatcher_rejection_summary_table\"[\\s\\S]*\"item\": \"dispatcher_rejection_trend_chart\"[\\s\\S]*\"item\": \"dispatcher_rejection_examples_table\"",
        splunk_data_ui_views.forge_runner_dispatcher_rejections.eai_data,
      ))
      && !strcontains(splunk_data_ui_views.forge_runner_dispatcher_rejections.eai_data, "\"operator_guide\"")
      && strcontains(splunk_data_ui_views.forge_runner_dispatcher_rejections.eai_data, "age_minutes")
    )
    error_message = "Dispatcher rejections must lead with actionable scope, expose age, and leave raw samples last without a guide row."
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_runner_dispatcher_rejections.eai_data, "sourcetype IN (\\\"aws:cloudwatchlogs\\\",\\\"aws:cloudwatchlogs:forgecicd\\\") source=\\\"*:/aws/lambda/*dispatch-to-runner:*\\\"")
      && strcontains(splunk_data_ui_views.forge_runner_dispatcher_rejections.eai_data, "| search forgecicd_log_type=\\\"dispatch-to-runner\\\"")
      && !strcontains(splunk_data_ui_views.forge_runner_dispatcher_rejections.eai_data, "index=\\\"srea-forge-prod-index\\\" forgecicd_log_type=")
    )
    error_message = "Dispatcher SPL must constrain indexed sourcetype and Lambda source before applying the search-time dispatcher field."
  }

  assert {
    condition = (
      !strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "\"operator_guide\"")
      && strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_debug.eai_data, "Use this drilldown only after the health dashboard")
      && strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_debug.eai_data, "Global locks are not assumed causal")
      && !strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_debug.eai_data, "\"operator_guide\"")
    )
    error_message = "Stuck-job health and debug dashboards must keep compact workflow guidance and the non-causal global-lock boundary."
  }
}
