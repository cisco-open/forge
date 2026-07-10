run "integrations_splunk_cloud_data_manager_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"splunk_cloudwatch\"",
      "module \"splunk_custom_cloudwatch\"",
      "module \"splunk_security_metadata\"",
      "module \"splunk_dm_metadata_ec2inst\"",
      "resource \"aws_cloudformation_stack\" \"cf_splunk_cloudwatch_iam_region\"",
      "resource \"aws_cloudformation_stack\" \"cf_splunk_cloudwatch_region\"",
      "resource \"aws_cloudformation_stack\" \"cf_splunk_custom_cloudwatch_iam_region\"",
      "resource \"aws_cloudformation_stack\" \"cf_splunk_custom_cloudwatch_region\"",
      "resource \"aws_cloudformation_stack\" \"cf_splunk_security_metadata_iam_region\"",
      "resource \"aws_cloudformation_stack\" \"cf_splunk_security_metadata_region\"",
      "resource \"null_resource\" \"splunk_dm_metadata_trigger\"",
      "data \"aws_cloudwatch_log_groups\" \"log_groups\"",
      "data \"aws_caller_identity\" \"current\"",
      "data \"aws_lambda_function\" \"splunk_dm_metadata_ec2inst\"",
      "output \"splunk_cloud_input_cloudwatch_logs_json\"",
      "output \"splunk_cloud_input_security_metadata_json\"",
      "output \"splunk_cloud_input_custom_logs_json\"",
      "provider \"aws\"",
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
