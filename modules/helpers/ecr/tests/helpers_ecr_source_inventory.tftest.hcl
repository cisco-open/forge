run "helpers_ecr_source_inventory" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"aws_ecr_repository\" \"ops_container_repository\"",
      "resource \"aws_ecr_lifecycle_policy\" \"ops_cleanup_policy\"",
      "output \"ops_container_repository_names\"",
      "provider \"aws\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 4
    error_message = "Source inventory must keep 4 module-specific Terraform blocks pinned."
  }
}
