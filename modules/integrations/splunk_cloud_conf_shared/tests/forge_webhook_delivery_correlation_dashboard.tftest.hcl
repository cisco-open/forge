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
}

run "adds_webhook_delivery_chain_gap_panel" {
  command = plan

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "\"delivery_chain_gaps_search\"")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "aws:cloudwatchlogs:forgecicd")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "*validate-signature*")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "age_seconds")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "tenant_webhook")
    )
    error_message = "The webhook dashboard must identify source-scoped delivery chains with a missing stage after the existing five-minute control-plane gate."
  }
}
