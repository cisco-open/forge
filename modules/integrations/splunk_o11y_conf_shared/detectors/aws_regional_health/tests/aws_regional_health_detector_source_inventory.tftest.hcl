run "aws_regional_health_detector_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_detector\" \"aws_regional_platform_health\"",
      "ApproximateAgeOfOldestMessage",
      "ApproximateNumberOfMessagesVisible",
      "NumberOfMessagesSent",
      "Build queue oldest age major",
      "Build queue backlog warning",
      "Queued-build DLQ activity",
      "__forge_aws_account_scope_not_configured__",
      "__forge_aws_region_scope_not_configured__",
      "__forge_product_family_scope_not_configured__",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Regional AWS detector source inventory is missing expected signals, rules, or fail-closed scope literals: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 10
    error_message = "Regional AWS detector source inventory count must remain pinned."
  }
}
