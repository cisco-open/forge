run "platform_forge_runners_github_global_lock_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"clean_global_lock_lambda\"",
      "resource \"aws_dynamodb_table\" \"lock_table\"",
      "resource \"aws_iam_policy\" \"dynamodb_policy\"",
      "resource \"aws_cloudwatch_log_group\" \"clean_global_lock_lambda\"",
      "resource \"aws_cloudwatch_event_rule\" \"clean_global_lock_lambda\"",
      "resource \"aws_cloudwatch_event_target\" \"clean_global_lock_lambda\"",
      "resource \"aws_lambda_permission\" \"clean_global_lock_lambda\"",
      "data \"aws_region\" \"current\"",
      "data \"aws_iam_policy_document\" \"dynamodb_policy_document\"",
      "data \"aws_iam_policy_document\" \"clean_global_lock_lambda\"",
      "output \"dynamodb_policy_arn\"",
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
