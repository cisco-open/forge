run "integrations_splunk_aws_billing_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"cur_per_resource\"",
      "module \"cur_per_resource_process\"",
      "module \"cur_per_service\"",
      "resource \"aws_lambda_permission\" \"cur_per_resource\"",
      "resource \"aws_cloudwatch_log_group\" \"cur_per_resource\"",
      "resource \"aws_bcmdataexports_export\" \"cur_per_resource\"",
      "resource \"aws_lambda_permission\" \"cur_per_resource_process\"",
      "resource \"aws_cloudwatch_log_group\" \"cur_per_resource_process\"",
      "resource \"aws_lambda_permission\" \"cur_per_service\"",
      "resource \"aws_cloudwatch_log_group\" \"cur_per_service\"",
      "resource \"aws_bcmdataexports_export\" \"cur_per_service\"",
      "resource \"aws_s3_bucket\" \"aws_billing_report\"",
      "resource \"aws_s3_bucket_ownership_controls\" \"aws_billing_report\"",
      "resource \"aws_s3_bucket_lifecycle_configuration\" \"aws_billing_report\"",
      "resource \"aws_s3_bucket_versioning\" \"aws_billing_report\"",
      "resource \"aws_s3_bucket_server_side_encryption_configuration\" \"aws_billing_report_settings\"",
      "resource \"aws_s3_bucket_public_access_block\" \"aws_billing_report\"",
      "resource \"aws_s3_bucket_policy\" \"cur_bucket_policy\"",
      "resource \"aws_s3_bucket_notification\" \"cur_notification\"",
      "data \"aws_caller_identity\" \"current\"",
      "data \"aws_partition\" \"current\"",
      "primary_billing_view_arn = \"arn:$${data.aws_partition.current.partition}:billing::$${data.aws_caller_identity.current.account_id}:billingview/primary\"",
      "BILLING_VIEW_ARN",
      "EnableAWSDataExportsToWriteToS3",
      "bcm-data-exports.amazonaws.com",
      "depends_on = [aws_s3_bucket_policy.cur_bucket_policy]",
      "data \"aws_iam_policy_document\" \"lambda_policy_document\"",
      "data \"aws_iam_policy_document\" \"cur_bucket_policy\"",
      "data \"aws_secretsmanager_secret\" \"secrets\"",
      "data \"aws_secretsmanager_secret_version\" \"secrets\"",
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
