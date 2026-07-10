mock_provider "aws" {
  mock_data "aws_secretsmanager_secret" {
    defaults = {
      id = "/cicd/common/splunk_cloud_api_token"
    }
  }

  mock_data "aws_secretsmanager_secret_version" {
    defaults = {
      secret_string = "mock-splunk-api-token"
    }
  }
}

mock_provider "splunk" {
  mock_resource "splunk_data_ui_views" {}
  mock_resource "splunk_configs_conf" {}
}

variables {
  aws_profile  = "test"
  aws_region   = "us-east-1"
  default_tags = { Product = "Forge" }
  splunk_conf = {
    splunk_cloud = "https://splunk.example.com"
    index        = "forge-prod-index"
    tenant_names = ["tenant-b", "tenant-a"]
    acl = {
      app     = "search"
      owner   = "nobody"
      sharing = "app"
      read    = ["*"]
      write   = ["admin"]
    }
  }
  stuck_workflow_job_dispatcher_name_prefix = "forge-dispatcher"
}

run "splunk_cloud_shared_dashboard_and_props_contract" {
  command = plan

  assert {
    condition = (
      splunk_data_ui_views.forge_ci_job_details.name == "forge_ci_job_details"
      && strcontains(splunk_data_ui_views.forge_ci_job_details.eai_data, "Forge CI Job Details")
      && strcontains(splunk_data_ui_views.forge_ci_job_details.eai_data, "forge-prod-index")
      && strcontains(splunk_data_ui_views.forge_ci_job_details.eai_data, "tenant-a")
      && strcontains(splunk_data_ui_views.forge_ci_job_details.eai_data, "tenant-b")
    )
    error_message = "Splunk shared config must render the CI job details dashboard from the configured index and sorted tenant list."
  }

  assert {
    condition = (
      splunk_data_ui_views.forge_ci_job_details.acl[0].app == "search"
      && splunk_data_ui_views.forge_ci_job_details.acl[0].owner == "nobody"
      && splunk_data_ui_views.forge_ci_job_details.acl[0].sharing == "app"
      && splunk_data_ui_views.forge_ci_job_details.acl[0].read[0] == "*"
      && splunk_data_ui_views.forge_ci_job_details.acl[0].write[0] == "admin"
    )
    error_message = "Splunk dashboards must propagate the configured ACL values."
  }

  assert {
    condition = (
      splunk_configs_conf.forgecicd_runner_logs_json.name == "props/forgecicd:runner-logs:json"
      && splunk_configs_conf.forgecicd_runner_logs_json.variables["REPORT-forgecicd_runner_logs_tenant_fields_event"] == "forgecicd_runner_logs_tenant_fields_event"
      && splunk_configs_conf.forgecicd_runner_logs_json.variables["REPORT-forgecicd_runner_ec2"] == "forgecicd_runner_ec2"
      && splunk_configs_conf.forgecicd_runner_logs_json.variables["REPORT-forgecicd_runner_arc"] == "forgecicd_runner_arc"
    )
    error_message = "Splunk shared props must keep JSON runner log sourcetype transforms for tenant, EC2, and ARC metadata."
  }
}
