run "dependency_probes_dashboard_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_dashboard\" \"dependency_health\"",
      "resource \"signalfx_list_chart\" \"github_availability\"",
      "resource \"signalfx_list_chart\" \"ssm_availability\"",
      "resource \"signalfx_list_chart\" \"rate_limit_budget\"",
      "resource \"signalfx_time_chart\" \"latency\"",
      "resource \"signalfx_time_chart\" \"probe_execution\"",
      "resource \"signalfx_time_chart\" \"tenant_health_alerts\"",
      "resource \"terraform_data\" \"dashboard_parent\"",
      "terraform_data.dashboard_parent,",
      "forge.dependency.availability",
      "forge.dependency.latency_ms",
      "forge.dependency.probe_executed",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Dependency dashboard is missing expected resources: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 12
    error_message = "Dependency dashboard source inventory count must remain pinned."
  }
}
