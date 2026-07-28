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

run "separates_stuck_job_path_from_global_lock_cleanup" {
  command = plan

  assert {
    condition = (
      strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "\"stuck_job_control_plane_path_search\"")
      && strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "webhook_queued")
      && strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "initial_dispatch")
      && strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "redelivery_completed")
      && strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "runner_in_progress")
      && strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "Forge Runner Capacity plus the EC2 or ARC lifecycle dashboard")
      && !strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "Redelivery and Global Lock Correlation")
    )
    error_message = "The stuck-job health dashboard must follow the webhook, dispatch, redelivery, and runner-start path without implying global-lock causality."
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "\"global_lock_cleanup_search\"")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "source=\\\"*:/aws/lambda/*clean-global-lock*:*\\\"")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "github_lookup_failed")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "malformed_lock_record")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "completed_lock_not_deleted")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "No stale-lock conclusion: lock age is not emitted")
    )
    error_message = "Global-lock cleanup must be diagnostic control-plane health and must not infer staleness without lock-age telemetry."
  }
}
