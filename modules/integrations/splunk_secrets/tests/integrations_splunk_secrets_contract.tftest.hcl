run "integrations_splunk_secrets_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"aws_kms_key\" \"regional\"",
      "resource \"aws_kms_alias\" \"regional_alias\"",
      "resource \"aws_secretsmanager_secret\" \"cicd_secrets\"",
      "resource \"time_sleep\" \"wait_60_seconds\"",
      "resource \"aws_secretsmanager_secret_version\" \"cicd_secrets\"",
      "data \"aws_secretsmanager_random_password\" \"secret_seeds\"",
      "provider \"aws\"",
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
