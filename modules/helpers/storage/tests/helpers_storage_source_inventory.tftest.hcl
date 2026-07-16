run "helpers_storage_source_inventory" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "data \"aws_caller_identity\" \"current\"",
      "resource \"aws_s3_bucket\" \"s3_long_term\"",
      "resource \"aws_s3_bucket_ownership_controls\" \"s3_long_term\"",
      "resource \"aws_s3_bucket_versioning\" \"s3_long_term\"",
      "resource \"aws_s3_bucket_server_side_encryption_configuration\" \"s3_long_term\"",
      "resource \"aws_s3_bucket_public_access_block\" \"s3_long_term\"",
      "resource \"aws_s3_bucket_policy\" \"config_delivery\"",
      "data \"aws_iam_policy_document\" \"config_delivery\"",
      "identifiers = [\"config.amazonaws.com\"]",
      "variable = \"AWS:SourceAccount\"",
      "\"s3:GetBucketAcl\"",
      "\"s3:ListBucket\"",
      "actions   = [\"s3:PutObject\"]",
      "resource \"aws_s3_bucket\" \"s3_short_term\"",
      "resource \"aws_s3_bucket_ownership_controls\" \"s3_short_term\"",
      "resource \"aws_s3_bucket_lifecycle_configuration\" \"s3_short_term\"",
      "resource \"aws_s3_bucket_versioning\" \"s3_short_term\"",
      "resource \"aws_s3_bucket_server_side_encryption_configuration\" \"s3_short_term_settings\"",
      "resource \"aws_s3_bucket_public_access_block\" \"s3_short_term\"",
      "output \"s3_short_term_settings\"",
      "output \"s3_long_term_settings\"",
      "provider \"aws\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 22
    error_message = "Source inventory must keep 22 module-specific Terraform blocks and AWS Config delivery permissions pinned."
  }
}
