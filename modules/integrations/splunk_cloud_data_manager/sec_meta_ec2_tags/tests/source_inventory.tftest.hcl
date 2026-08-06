run "integrations_splunk_cloud_data_manager_sec_meta_ec2_tags_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"splunk_dm_metadata_ec2inst_pattern_tags_lambda\"",
      "resource \"aws_cloudwatch_log_group\" \"splunk_dm_metadata_ec2inst_pattern_tags_lambda\"",
      "resource \"aws_cloudwatch_event_rule\" \"splunk_dm_metadata_ec2inst_pattern_tags_lambda\"",
      "resource \"aws_cloudwatch_event_target\" \"splunk_dm_metadata_ec2inst_pattern_tags_lambda\"",
      "resource \"aws_lambda_permission\" \"splunk_dm_metadata_ec2inst_pattern_tags_lambda\"",
      "data \"aws_iam_policy_document\" \"splunk_dm_metadata_ec2inst_pattern_tags_lambda\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Module contract is missing expected literals: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count > 0
    error_message = "Module contract must pin at least one module-specific literal."
  }
}
