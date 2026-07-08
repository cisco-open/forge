run "integrations_github_webhook_relay_destination_receivers_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"webhook_relay_destination\"",
      "module \"webex_webhook_relay\"",
      "data \"aws_caller_identity\" \"current\"",
      "output \"role_arn\"",
      "output \"webhook\"",
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
