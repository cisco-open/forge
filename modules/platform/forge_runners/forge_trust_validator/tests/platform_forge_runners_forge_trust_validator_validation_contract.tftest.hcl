run "iam_propagation_delay_validation_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "validation {",
      "var.iam_propagation_delay_seconds >= 0",
      "var.iam_propagation_delay_seconds <= 900",
      "error_message = \"iam_propagation_delay_seconds must be between 0 and 900.\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Forge trust validator validation contract is missing expected literals: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count > 0
    error_message = "Forge trust validator validation contract must pin at least one validation literal."
  }
}
