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

run "adds_redelivery_global_lock_correlation" {
  command = plan

  assert {
    condition = (
      strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "\"redelivery_lock_correlation_search\"")
      && strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "source=\\\"*:/aws/lambda/*clean-global-lock*:*\\\"")
      && strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "global_lock_cleanup_lookup_failed")
      && strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "global_lock_cleanup_deleted")
      && strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "run_id")
    )
    error_message = "The stuck-job health dashboard must correlate redelivery requests with structured global-lock outcomes by workflow run."
  }
}
