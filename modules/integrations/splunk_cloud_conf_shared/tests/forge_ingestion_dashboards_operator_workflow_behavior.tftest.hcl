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
      ] :
      !strcontains(body, "\"operator_guide\"")
      && !strcontains(body, "\"type\": \"splunk.markdown\"")
      && strcontains(body, "\"description\": \"Answers")
      && strcontains(body, "$global_time.earliest$")
      && strcontains(body, "$global_time.latest$")
    ])
    error_message = "Ingestion dashboards must keep guidance in panel descriptions and retain the global-time token."
  }

  assert {
    condition = (
      can(regex("\"item\": \"missing_fields_table\"[\\s\\S]*\"item\": \"volume_anomaly_chart\"[\\s\\S]*\"item\": \"source_inventory_table\"", splunk_data_ui_views.forge_ingestion_quality.eai_data))
      && can(regex("\"item\": \"lambda_errors_table\"[\\s\\S]*\"item\": \"lambda_error_trend_chart\"[\\s\\S]*\"item\": \"lambda_samples_table\"", splunk_data_ui_views.forge_lambda_operations.eai_data))
      && strcontains(splunk_data_ui_views.forge_ingestion_quality.eai_data, "forgecicd:runner-logs:s3")
      && !strcontains(splunk_data_ui_views.forge_ingestion_quality.eai_data, "splunk-s3-runner-logs")
      && !strcontains(splunk_data_ui_views.forge_lambda_operations.eai_data, "splunk-s3-runner-logs")
    )
    error_message = "Ingestion and Lambda dashboards must retain useful diagnostics without references to the retired runner-log streaming pipeline."
  }
}
