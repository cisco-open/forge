run "helpers_ami_policy_source_inventory" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"aws_ebs_encryption_by_default\" \"gpol_encrypt_ebs\"",
      "resource \"aws_iam_role\" \"dlm_lifecycle_role\"",
      "resource \"aws_iam_role_policy\" \"dlm_lifecycle\"",
      "resource \"aws_dlm_lifecycle_policy\" \"dlm_lifecycle\"",
      "provider \"aws\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 5
    error_message = "Source inventory must keep 5 module-specific Terraform blocks pinned."
  }
}
