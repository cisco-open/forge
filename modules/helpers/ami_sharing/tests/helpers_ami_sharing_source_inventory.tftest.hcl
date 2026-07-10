run "helpers_ami_sharing_source_inventory" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "data \"aws_ami\" \"selected\"",
      "resource \"aws_ami_launch_permission\" \"share_amis\"",
      "provider \"aws\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 3
    error_message = "Source inventory must keep 3 module-specific Terraform blocks pinned."
  }
}
