run "helpers_service_linked_roles_source_inventory" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"aws_iam_service_linked_role\" \"spot\"",
      "from = aws_iam_service_linked_role.license_manager",
      "destroy = false",
      "provider \"aws\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 4
    error_message = "Source inventory must keep 4 module-specific Terraform source contracts pinned."
  }
}
