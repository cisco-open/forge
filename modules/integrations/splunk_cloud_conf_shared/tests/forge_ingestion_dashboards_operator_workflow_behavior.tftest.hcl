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

run "orders_ingestion_dashboards_for_operator_triage" {
  command = plan

  assert {
    condition = alltrue([
      for body in [
        splunk_data_ui_views.forge_ingestion_quality.eai_data,
        splunk_data_ui_views.forge_lambda_operations.eai_data,
        splunk_data_ui_views.forge_webhook_job_log_pipeline.eai_data,
      ] :
      strcontains(body, "How should I use this dashboard?")
      && strcontains(body, "Healthy:")
      && strcontains(body, "Action:")
      && strcontains(body, "\"description\": \"Answers")
      && strcontains(body, "$global_time.earliest$")
      && strcontains(body, "$global_time.latest$")
    ])
    error_message = "Ingestion dashboards must explain healthy/action semantics per panel and retain the global-time token."
  }

  assert {
    condition = (
      can(regex("\"item\": \"operator_guide\"[\\s\\S]*\"item\": \"missing_fields_table\"[\\s\\S]*\"item\": \"volume_anomaly_chart\"[\\s\\S]*\"item\": \"source_inventory_table\"", splunk_data_ui_views.forge_ingestion_quality.eai_data))
      && can(regex("\"item\": \"operator_guide\"[\\s\\S]*\"item\": \"lambda_errors_table\"[\\s\\S]*\"item\": \"lambda_error_trend_chart\"[\\s\\S]*\"item\": \"lambda_samples_table\"", splunk_data_ui_views.forge_lambda_operations.eai_data))
    )
    error_message = "Actionable ingestion and Lambda failures must appear before trends, source inventory, and raw samples."
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_webhook_job_log_pipeline.eai_data, "unequal broad totals alone are not proof of loss")
      && strcontains(splunk_data_ui_views.forge_webhook_job_log_pipeline.eai_data, "Which job-log archive operations failed?")
    )
    error_message = "The job-log pipeline dashboard must distinguish confirmed failures from non-causal count differences."
  }
}
