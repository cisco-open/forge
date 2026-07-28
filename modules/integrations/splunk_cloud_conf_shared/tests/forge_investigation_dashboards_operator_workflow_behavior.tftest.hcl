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

run "makes_investigation_dashboards_explicitly_diagnostic" {
  command = plan

  assert {
    condition = alltrue([
      for body in [
        splunk_data_ui_views.forge_ci_job_details.eai_data,
        splunk_data_ui_views.forge_tenant_logs.eai_data,
        splunk_data_ui_views.forge_troubleshooting.eai_data,
      ] :
      !strcontains(body, "\"operator_guide\"")
      && !strcontains(body, "\"type\": \"splunk.markdown\"")
      && strcontains(body, "\"description\":")
    ])
    error_message = "Investigation dashboards must keep guidance in compact panel descriptions rather than a dedicated guide row."
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_tenant_logs.eai_data, "Which tenant log events match the investigation?")
      && strcontains(splunk_data_ui_views.forge_tenant_logs.eai_data, "an empty result can mean no matching retained events")
      && strcontains(splunk_data_ui_views.forge_tenant_logs.eai_data, "Raw logs provide evidence but do not assign")
    )
    error_message = "Tenant logs must not present an empty raw-event result as proof of health or assign ownership by itself."
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_ci_job_details.eai_data, "\"description\": \"Answers")
      && strcontains(splunk_data_ui_views.forge_troubleshooting.eai_data, "\"description\": \"Answers")
      && can(regex("\"item\": \"queued_windows_table\"[\\s\\S]*\"item\": \"ci_job_details_table\"", splunk_data_ui_views.forge_ci_job_details.eai_data))
    )
    error_message = "CI and troubleshooting panels must have question-oriented descriptions and leave high-cardinality job detail after queue diagnostics."
  }
}
