run "integrations_splunk_cloud_s3_runner_logs_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"splunk_s3_runner_logs_lambda\"",
      "resource \"aws_iam_role\" \"firehose_role\"",
      "resource \"aws_iam_policy\" \"firehose_policy\"",
      "resource \"aws_iam_role_policy_attachment\" \"firehose_attach\"",
      "resource \"aws_kinesis_firehose_delivery_stream\" \"splunk_firehose\"",
      "resource \"aws_cloudwatch_log_group\" \"firehose_splunk\"",
      "resource \"aws_kinesis_stream\" \"splunk_s3_runner_logs\"",
      "resource \"aws_kms_key\" \"splunk_s3_runner_logs\"",
      "resource \"aws_kms_alias\" \"splunk_s3_runner_logs\"",
      "resource \"aws_cloudwatch_log_group\" \"splunk_s3_runner_logs_lambda\"",
      "resource \"aws_lambda_event_source_mapping\" \"sqs_to_lambda\"",
      "resource \"aws_s3_bucket_notification\" \"logs\"",
      "resource \"aws_s3_bucket\" \"firehose_backup\"",
      "resource \"aws_s3_bucket_ownership_controls\" \"firehose_backup\"",
      "resource \"aws_s3_bucket_versioning\" \"firehose_backup\"",
      "resource \"aws_s3_bucket_server_side_encryption_configuration\" \"firehose_backup\"",
      "resource \"aws_s3_bucket_public_access_block\" \"firehose_backup\"",
      "resource \"aws_sqs_queue\" \"log_events_queue\"",
      "resource \"aws_sqs_queue\" \"log_events_dlq\"",
      "resource \"aws_sqs_queue_policy\" \"allow_s3\"",
      "data \"aws_caller_identity\" \"current\"",
      "data \"aws_iam_policy_document\" \"kms_s3\"",
      "data \"aws_iam_policy_document\" \"splunk_s3_runner_logs_lambda\"",
      "data \"external\" \"s3_buckets\"",
      "data \"aws_secretsmanager_secret\" \"secrets\"",
      "data \"aws_secretsmanager_secret_version\" \"secrets\"",
      "data \"aws_iam_policy_document\" \"allow_s3\"",
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
