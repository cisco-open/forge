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

run "separates_dispatcher_coverage_from_relay_health" {
  command = plan

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "\"queued_webhook_dispatch_coverage_search\"")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "\"webhook_relay_health_search\"")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "aws:cloudwatchlogs:forgecicd")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "age_seconds")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "queued_webhook")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "dispatcher_decision")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "missing_workflow_job_ids")
      && !strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "\"delivery_chain_gaps_search\"")
      && !strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "workflow_ids_by_delivery")
    )
    error_message = "The webhook dashboard must correlate queued jobs to dispatcher decisions by workflow-job ID without claiming a relay-to-tenant join."
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "*validate-signature*")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Received GitHub webhook")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Signature mismatch")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Event forwarded to EventBridge")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "eventbridge_failed")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "lambda_error")
    )
    error_message = "Relay receipt, rejection, forwarding, and Lambda failures must remain a separate shared-platform health signal."
  }
}
