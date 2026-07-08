run "platform_forge_runners_github_app_runner_group_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"register_github_app_runner_group_lambda\"",
      "resource \"aws_cloudwatch_log_group\" \"register_github_app_runner_group_lambda\"",
      "resource \"aws_cloudwatch_event_rule\" \"register_github_app_runner_group_lambda\"",
      "resource \"aws_cloudwatch_event_target\" \"register_github_app_runner_group_lambda\"",
      "resource \"aws_lambda_permission\" \"register_github_app_runner_group_lambda\"",
      "data \"aws_region\" \"current\"",
      "data \"aws_iam_policy_document\" \"register_github_app_runner_group_lambda\"",
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
