run "repository_selection_validation_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "validation {",
      "condition     = contains([\"all\", \"selected\"], var.deployment_config.github.repository_selection)",
      "error_message = \"repository_selection must be 'all' or 'selected'.\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Forge runners validation contract is missing expected literals: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count > 0
    error_message = "Forge runners validation contract must pin at least one validation literal."
  }
}
