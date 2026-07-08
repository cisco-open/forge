run "platform_forge_runners_github_webhook_relay_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"github_webhook_relay_source\"",
      "resource \"random_id\" \"github_webhook_relay_source_secret\"",
      "resource \"aws_kms_key\" \"github_webhook_relay\"",
      "resource \"aws_kms_alias\" \"github_webhook_relay\"",
      "resource \"aws_secretsmanager_secret\" \"github_webhook_relay\"",
      "resource \"aws_secretsmanager_secret_version\" \"github_webhook_relay\"",
      "resource \"aws_iam_role\" \"secret_reader\"",
      "resource \"aws_iam_role_policy\" \"secret_reader_inline\"",
      "data \"aws_region\" \"current\"",
      "data \"aws_iam_policy_document\" \"secret_reader_trust\"",
      "data \"aws_iam_policy_document\" \"secret_reader_permissions\"",
      "output \"source_secret_arn\"",
      "output \"source_secret_role_arn\"",
      "output \"source_secret_region\"",
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
