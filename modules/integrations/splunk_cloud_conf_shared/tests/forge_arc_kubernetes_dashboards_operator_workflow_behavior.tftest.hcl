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

run "orders_arc_and_kubernetes_dashboards_for_operator_triage" {
  command = plan

  assert {
    condition = alltrue([
      for body in [
        splunk_data_ui_views.forge_arc_dind_runner_lifecycle.eai_data,
        splunk_data_ui_views.forge_arc_k8s_runner_lifecycle.eai_data,
        splunk_data_ui_views.forge_kubernetes_storage_and_network.eai_data,
      ] :
      !strcontains(body, "\"operator_guide\"")
      && !strcontains(body, "\"type\": \"splunk.markdown\"")
      && strcontains(body, "\"description\": \"Answers")
    ])
    error_message = "ARC and Kubernetes dashboards must keep guidance in compact panel descriptions."
  }

  assert {
    condition = (
      can(regex("\"item\": \"init_failures_table\"[\\s\\S]*\"item\": \"dind_trend_chart\"[\\s\\S]*\"item\": \"runner_version_table\"", splunk_data_ui_views.forge_arc_dind_runner_lifecycle.eai_data))
      && can(regex("\"item\": \"k8s_pod_events_table\"[\\s\\S]*\"item\": \"k8s_hook_trend_chart\"[\\s\\S]*\"item\": \"k8s_runner_version_table\"", splunk_data_ui_views.forge_arc_k8s_runner_lifecycle.eai_data))
    )
    error_message = "ARC lifecycle dashboards must place actionable pod, PVC, hook, and init failures before trends and inventory."
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_kubernetes_storage_and_network.eai_data, "This is diagnostic proximity, not proof of causality")
      && strcontains(splunk_data_ui_views.forge_kubernetes_storage_and_network.eai_data, "validate the exact workflow job and resource identifiers")
    )
    error_message = "Kubernetes job-overlap panels must explicitly avoid claiming causality from time-window proximity."
  }
}
