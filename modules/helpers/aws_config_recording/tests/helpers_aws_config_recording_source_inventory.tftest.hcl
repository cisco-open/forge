run "helpers_aws_config_recording_source_inventory" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"aws_config_configuration_recorder\" \"dedicated_hosts\"",
      "resource \"aws_config_delivery_channel\" \"dedicated_hosts\"",
      "resource \"aws_config_configuration_recorder_status\" \"dedicated_hosts\"",
      "resource \"aws_s3_bucket\" \"config_delivery\"",
      "resource \"aws_s3_bucket_public_access_block\" \"config_delivery\"",
      "resource \"aws_s3_bucket_server_side_encryption_configuration\" \"config_delivery\"",
      "resource \"aws_s3_bucket_versioning\" \"config_delivery\"",
      "resource \"aws_iam_role\" \"config\"",
      "\"AWS::EC2::Host\"",
      "\"AWS::EC2::Instance\"",
      "provider \"aws\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 11
    error_message = "Source inventory must keep 11 AWS Config Terraform blocks and literals pinned."
  }
}
