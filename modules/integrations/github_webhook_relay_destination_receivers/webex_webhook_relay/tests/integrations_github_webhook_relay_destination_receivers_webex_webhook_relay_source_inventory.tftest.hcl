run "integrations_github_webhook_relay_destination_receivers_webex_webhook_relay_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"webex\"",
      "resource \"aws_cloudwatch_log_group\" \"webex\"",
      "resource \"aws_kms_key\" \"webex\"",
      "resource \"aws_kms_alias\" \"webex_alias\"",
      "resource \"aws_secretsmanager_secret\" \"cicd_secrets\"",
      "resource \"time_sleep\" \"wait_60_seconds\"",
      "resource \"aws_secretsmanager_secret_version\" \"cicd_secrets\"",
      "data \"aws_iam_policy_document\" \"secret\"",
      "data \"aws_secretsmanager_random_password\" \"secret_seeds\"",
      "output \"lambda_function_arn\"",
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
