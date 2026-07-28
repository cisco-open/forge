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
  mock_resource "splunk_saved_searches" {}
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

run "creates_role_aware_trust_alert" {
  command = plan

  assert {
    condition = (
      splunk_saved_searches.forge_iam_trust_failures.name == "Forge IAM trust validation failures"
      && splunk_saved_searches.forge_iam_trust_failures.cron_schedule == "*/15 * * * *"
      && splunk_saved_searches.forge_iam_trust_failures.dispatch_earliest_time == "-24h"
      && splunk_saved_searches.forge_iam_trust_failures.alert_type == "number of events"
      && splunk_saved_searches.forge_iam_trust_failures.alert_comparator == "greater than"
      && splunk_saved_searches.forge_iam_trust_failures.alert_threshold == "0"
      && splunk_saved_searches.forge_iam_trust_failures.alert_track
    )
    error_message = "The trust alert must run every 15 minutes and track any failed latest validation edge."
  }

  assert {
    condition = (
      startswith(trimspace(splunk_saved_searches.forge_iam_trust_failures.search), "index=\"srea-forge-prod-index\" sourcetype=\"aws:cloudwatchlogs\" source=\"*:/aws/lambda/*forge-trust-validator*\"")
      && strcontains(splunk_saved_searches.forge_iam_trust_failures.search, "\"Delayed validation run complete\"")
      && strcontains(splunk_saved_searches.forge_iam_trust_failures.search, "eventstats max(_time) as latest_validation by validator_tenant")
      && strcontains(splunk_saved_searches.forge_iam_trust_failures.search, "assume_ok!=\"true\" OR tag_ok!=\"true\"")
      && strcontains(splunk_saved_searches.forge_iam_trust_failures.search, "tenant_role_arn")
      && strcontains(splunk_saved_searches.forge_iam_trust_failures.search, "assume_role_error")
      && strcontains(splunk_saved_searches.forge_iam_trust_failures.search, "tag_session_error")
    )
    error_message = "The alert must use indexed source filters and preserve role, action, and failure context from the latest completed validation."
  }
}
