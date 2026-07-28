run "aws_regional_health_dashboard_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_time_chart\" \"lambda_throttle_attempt_rate\"",
      "resource \"signalfx_time_chart\" \"lambda_throttle_count\"",
      "resource \"signalfx_time_chart\" \"build_queue_oldest_age\"",
      "resource \"signalfx_time_chart\" \"build_queue_visible_backlog\"",
      "resource \"signalfx_time_chart\" \"build_queue_dlq_sends\"",
      "resource \"signalfx_time_chart\" \"queue_health_alerts\"",
      "resource \"signalfx_text_chart\" \"operator_guide\"",
      "resource \"terraform_data\" \"dashboard_parent\"",
      "terraform_data.dashboard_parent,",
      "resource \"signalfx_dashboard\" \"aws_regional_health\"",
      "Forge AWS Regional Platform Health",
      "__forge_aws_account_scope_not_configured__",
      "__forge_aws_region_scope_not_configured__",
      "__forge_product_family_scope_not_configured__",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Regional AWS dashboard source inventory is missing expected Terraform or fail-closed scope literals: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 14
    error_message = "Regional AWS dashboard source inventory count must remain pinned."
  }
}
