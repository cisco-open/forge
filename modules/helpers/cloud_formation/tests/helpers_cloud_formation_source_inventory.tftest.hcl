run "helpers_cloud_formation_source_inventory" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "data \"aws_caller_identity\" \"current\"",
      "data \"aws_iam_policy_document\" \"cloudformation_assume_role_policy\"",
      "resource \"aws_iam_role\" \"cloudformation_admin_role\"",
      "data \"aws_iam_policy_document\" \"admin_assume_execution_role_policy\"",
      "resource \"aws_iam_role_policy\" \"admin_assume_execution_role_policy_attachment\"",
      "data \"aws_iam_policy_document\" \"execution_assume_admin_role_policy\"",
      "resource \"aws_iam_role\" \"cloudformation_execution_role\"",
      "data \"aws_iam_policy_document\" \"execution_role_policy\"",
      "resource \"aws_iam_role_policy\" \"execution_role_policy_attachment\"",
      "provider \"aws\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 10
    error_message = "Source inventory must keep 10 module-specific Terraform blocks pinned."
  }
}
