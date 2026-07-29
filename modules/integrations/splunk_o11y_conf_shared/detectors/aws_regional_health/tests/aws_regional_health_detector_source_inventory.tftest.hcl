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
      "resource \"signalfx_detector\" \"runner_log_delivery_health\"",
      "ApproximateAgeOfOldestMessage",
      "ApproximateNumberOfMessagesVisible",
      "NumberOfMessagesSent",
      "KinesisMillisBehindLatest",
      "DataReadFromKinesisStream.Records",
      "ThrottledGetRecords",
      "ThrottledGetShardIterator",
      "Control-plane Lambda errors",
      "Control-plane Lambda throttles",
      "Control-plane DLQ backlog",
      "Build queue oldest age major",
      "Build queue backlog warning",
      "Queued-build DLQ activity",
      "Runner-log Firehose source lag warning",
      "Runner-log Firehose source lag critical",
      "Runner-log Firehose source throttled",
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
    condition     = output.expected_literal_count == 23
    error_message = "Regional AWS detector source inventory count must remain pinned."
  }
}
