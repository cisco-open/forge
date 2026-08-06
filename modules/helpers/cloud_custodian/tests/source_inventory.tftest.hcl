run "helpers_cloud_custodian_source_inventory" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "data \"aws_iam_policy_document\" \"cloud_custodian_policy\"",
      "resource \"aws_iam_policy\" \"cloud_custodian_policy\"",
      "data \"aws_iam_policy_document\" \"assume_role_for_cloud_custodian\"",
      "resource \"aws_iam_role_policy_attachment\" \"attach_cloud_custodian_policy\"",
      "resource \"aws_iam_role\" \"cloud_custodian\"",
      "provider \"aws\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 6
    error_message = "Source inventory must keep 6 module-specific Terraform blocks pinned."
  }
}
