run "aws_regional_health_detector_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_detector\" \"aws_regional_platform_health\"",
      "resource \"signalfx_detector\" \"aws_control_plane_health\"",
      "resource \"signalfx_detector\" \"aws_sqs_control_plane_health\"",
      "ApproximateAgeOfOldestMessage",
      "ApproximateNumberOfMessagesVisible",
      "NumberOfMessagesSent",
      "Control-plane Lambda errors",
      "Control-plane Lambda throttles",
      "Control-plane DLQ backlog",
      "Dependency monitor retries exhausted",
      "Build queue oldest age major",
      "Build queue backlog warning",
      "Queued-build DLQ activity",
      "for variable in var.dynamic_variables",
      "concat(variable.values, variable.values_suggested)",
      "__forge_dynamic_scope_not_configured__",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Regional AWS detector source inventory is missing expected signals, rules, or fail-closed scope literals: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 16
    error_message = "Regional AWS detector source inventory count must remain pinned."
  }
}
