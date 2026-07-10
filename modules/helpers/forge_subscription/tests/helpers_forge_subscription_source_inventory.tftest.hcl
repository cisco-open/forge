run "helpers_forge_subscription_source_inventory" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "data \"aws_iam_policy_document\" \"ecr_repository_policy\"",
      "resource \"aws_ecr_repository_policy\" \"repository_policy\"",
      "data \"aws_iam_policy_document\" \"s3_access_for_forge_runners\"",
      "data \"aws_iam_policy_document\" \"secrets_access_for_forge_runners\"",
      "data \"aws_iam_policy_document\" \"packer_support_for_forge_runners\"",
      "resource \"aws_iam_role_policy\" \"s3_access_for_forge_runners\"",
      "resource \"aws_iam_role_policy\" \"secrets_access_for_forge_runners\"",
      "resource \"aws_iam_role_policy\" \"packer_support_for_forge_runners\"",
      "provider \"aws\"",
      "data \"aws_iam_policy_document\" \"assume_role_for_forge_runners\"",
      "resource \"aws_iam_role\" \"role_for_forge_runners\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 11
    error_message = "Source inventory must keep 11 module-specific Terraform blocks pinned."
  }
}
