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

run "organizes_webhook_health_for_operator_triage" {
  command = plan

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "\"queued_jobs_base_search\"")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "\"queued_jobs_search\"")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "\"queued_jobs_summary_search\"")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "\"webhook_relay_health_search\"")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "aws:cloudwatchlogs:forgecicd")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "source=\\\"*:/aws/lambda/*-webhook:*\\\"")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "age_seconds")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "queued_webhook")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "runner_in_progress")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "runner_completed")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "age_seconds>900 AND age_seconds<=86400")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "spath path=github.workflowJobId output=workflow_job_id")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "ds.chain")
      && !strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Successfully dispatched job for")
      && !strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Received event contains runner labels")
      && !strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "source=\\\"*:/aws/lambda/*-dispatch-to-runner:*\\\"")
      && !strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "\"delivery_chain_gaps_search\"")
      && !strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "workflow_ids_by_delivery")
    )
    error_message = "The webhook dashboard must derive queued-job aging from structured webhook lifecycle fields without legacy dispatcher parsing or an unsupported relay-to-tenant join."
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

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Workflow jobs still queued")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Healthy: 0")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Healthy: no rows")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Which workflow jobs remain queued?")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Is the shared webhook relay forwarding events?")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "How is workflow-job activity trending?")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Which workflow-job webhook events were received?")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "timechart span=15m dc(workflow_job_id) by status")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "operator_action")
      && !strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "\"operator_guide\"")
      && !strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "\"type\": \"splunk.markdown\"")
    )
    error_message = "The webhook dashboard must explain healthy results, ask operator-oriented questions, add workflow trends, and avoid a dedicated guide row."
  }

  assert {
    condition = (
      length(regexall("(?s)\"item\":\\s*\"queued_jobs_single\".*?\"y\":\\s*0", splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data)) == 1
      && length(regexall("(?s)\"item\":\\s*\"queued_jobs_table\".*?\"y\":\\s*220", splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data)) == 1
      && length(regexall("(?s)\"item\":\\s*\"webhook_relay_health_chart\".*?\"y\":\\s*580", splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data)) == 1
      && length(regexall("(?s)\"item\":\\s*\"workflow_activity_trend_chart\".*?\"y\":\\s*1200", splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data)) == 1
      && length(regexall("(?s)\"item\":\\s*\"github_webhook_workflow_jobs_table\".*?\"y\":\\s*2260", splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data)) == 1
    )
    error_message = "The dashboard must order queued-job summary cards, the actionable queue table, relay health, trends, and raw events from top to bottom."
  }
}
