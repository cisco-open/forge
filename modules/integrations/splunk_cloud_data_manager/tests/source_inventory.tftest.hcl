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
      "module \"splunk_s3_logs\"",
      "module \"splunk_security_metadata\"",
      "module \"splunk_dm_metadata_ec2inst\"",
      "module \"splunk_dm_log_group_reconciler\"",
      "resource \"aws_lambda_invocation\" \"splunk_dm_log_group_reconciler\"",
      "lifecycle_scope = \"CREATE_ONLY\"",
      "region          = each.key",
      "resource \"aws_cloudformation_stack\" \"cf_splunk_cloudwatch_iam_region\"",
      "resource \"aws_cloudformation_stack\" \"cf_splunk_cloudwatch_region\"",
      "resource \"aws_cloudformation_stack\" \"cf_splunk_custom_cloudwatch_iam_region\"",
      "resource \"aws_cloudformation_stack\" \"cf_splunk_custom_cloudwatch_region\"",
      "resource \"aws_cloudformation_stack\" \"cf_splunk_s3_logs_iam_region\"",
      "name     = module.splunk_s3_logs[each.key].splunk_integration_name",
      "template_url = module.splunk_s3_logs[each.key].splunk_integration_template_url",
      "tags = module.splunk_s3_logs[each.key].splunk_integration_tags",
      "tags_all = module.splunk_s3_logs[each.key].splunk_integration_tags_all",
      "depends_on = [\n    module.splunk_s3_logs,\n    module.splunk_dm_log_group_reconciler,\n  ]",
      "resource \"aws_cloudformation_stack\" \"cf_splunk_security_metadata_iam_region\"",
      "resource \"aws_cloudformation_stack\" \"cf_splunk_security_metadata_region\"",
      "resource \"null_resource\" \"splunk_dm_metadata_trigger\"",
      "data \"aws_cloudwatch_log_groups\" \"log_groups\"",
      "data \"aws_caller_identity\" \"current\"",
      "data \"aws_lambda_function\" \"splunk_dm_metadata_ec2inst\"",
      "local.application_config_aliases",
      "var.custom_cloudwatch_log_groups_config.enabled ? \"custom-cwl\" : \"\"",
      "var.cloudwatch_log_groups_config.enabled ? \"cwl\" : \"\"",
      "length(local.splunk_s3_logs_inputs) > 0 ? \"s3-logs\" : \"\"",
      "region   = each.value.iam_region",
      "var.security_metadata_config.enabled ? \"secmeta\" : \"\"",
      "[\"integrations_splunk_cloud_data_manager\"]",
      "[var.aws_region]",
      "output \"splunk_cloud_input_cloudwatch_logs_json\"",
      "output \"splunk_cloud_input_security_metadata_json\"",
      "output \"splunk_cloud_input_custom_logs_json\"",
      "output \"splunk_cloud_input_s3_logs_json\"",
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
