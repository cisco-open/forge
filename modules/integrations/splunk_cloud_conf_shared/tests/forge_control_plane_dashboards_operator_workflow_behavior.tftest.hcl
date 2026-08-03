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

run "orders_control_plane_dashboards_for_operator_triage" {
  command = plan

  assert {
    condition = alltrue([
      for body in [
        splunk_data_ui_views.forge_runner_capacity.eai_data,
        splunk_data_ui_views.forge_runner_control_plane_health.eai_data,
        splunk_data_ui_views.forge_trust_failures.eai_data,
      ] :
      !strcontains(body, "\"operator_guide\"")
      && !strcontains(body, "\"type\": \"splunk.markdown\"")
      && strcontains(body, "\"description\": \"Answers")
    ])
    error_message = "Capacity, control-plane, and trust dashboards must keep guidance in compact panel descriptions."
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_runner_capacity.eai_data, "One elevated percentile is not enough to infer failure")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "Global-lock cleanup is diagnostic and is not causal evidence for a stuck job")
      && strcontains(splunk_data_ui_views.forge_trust_failures.eai_data, "TagSession")
    )
    error_message = "Control-plane guidance must prevent single-chart failure inference, false global-lock causality, and incomplete STS trust triage."
  }

  assert {
    condition = (
      can(regex("\"item\": \"queue_pressure_table\"[\\s\\S]*\"item\": \"queue_trend_chart\"", splunk_data_ui_views.forge_runner_capacity.eai_data))
      && can(regex("\"item\": \"assume_role_failures_table\"[\\s\\S]*\"item\": \"trust_failure_trend_chart\"[\\s\\S]*\"item\": \"latest_validation_table\"", splunk_data_ui_views.forge_trust_failures.eai_data))
    )
    error_message = "Capacity and trust dashboards must place actionable failures before trend and investigation detail."
  }

  assert {
    condition = (
      can(jsondecode(local.forge_runner_control_plane_health_definition))
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "GitHub rate limit: Request quota exhausted")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "isJobQueued check failed, assuming job is still queued (fail-open)")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "body is not valid JSON")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "SQS messages will be retried.")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "Checking current ec2 pool size")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "Runner creation summary.")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "requestedMessageCount")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "Failed to mark EC2 runner")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "EC2 runner '(?<provider_instance_id>")
    )
    error_message = "Runner control-plane searches must use only the v7.10.1 API, SQS, pool, scale-up, and scale-down log contract."
  }

  assert {
    condition = (
      splunk_configs_conf.forgecicd_pool_target_size.variables.REGEX == "Checking current ec2 pool size against pool of size: ([0-9]+)"
      && splunk_configs_conf.forgecicd_scale_down_aws_runner_instance_id.variables.REGEX == "EC2 runner '(i-[0-9a-f]+)'"
    )
    error_message = "Control-plane field extractions must use only the v7.10.1 provider-aware messages."
  }
}
