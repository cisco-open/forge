run "platform_forge_runners_redrive_deadletter_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"redrive_deadletter_lambda\"",
      "resource \"aws_cloudwatch_log_group\" \"redrive_deadletter_lambda\"",
      "resource \"aws_cloudwatch_event_rule\" \"redrive_deadletter_lambda\"",
      "resource \"aws_cloudwatch_event_target\" \"redrive_deadletter_lambda\"",
      "resource \"aws_lambda_permission\" \"redrive_deadletter_lambda\"",
      "data \"aws_iam_policy_document\" \"redrive_deadletter_lambda\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Module contract is missing expected literals: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count > 0
    error_message = "Module contract must pin at least one module-specific literal."
  }
}
