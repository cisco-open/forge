run "platform_forge_runners_github_actions_job_logs_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"job_log_archiver\"",
      "module \"job_log_dispatcher\"",
      "resource \"aws_cloudwatch_log_group\" \"job_log_archiver\"",
      "resource \"aws_lambda_event_source_mapping\" \"job_log_archiver\"",
      "resource \"aws_lambda_permission\" \"scale_runners_lambda\"",
      "resource \"aws_cloudwatch_log_group\" \"job_log_dispatcher\"",
      "resource \"aws_lambda_permission\" \"job_log_dispatcher\"",
      "resource \"aws_cloudwatch_event_rule\" \"job_log_dispatcher\"",
      "resource \"aws_cloudwatch_event_target\" \"job_log_dispatcher\"",
      "resource \"aws_iam_role\" \"internal_s3_reader\"",
      "resource \"aws_iam_policy\" \"internal_s3_reader_policy\"",
      "resource \"aws_iam_role_policy_attachment\" \"attach_internal_s3_reader\"",
      "resource \"aws_s3_bucket\" \"gh_logs\"",
      "resource \"aws_s3_bucket_ownership_controls\" \"gh_logs\"",
      "resource \"aws_s3_bucket_versioning\" \"gh_logs\"",
      "resource \"aws_kms_key\" \"gh_logs\"",
      "resource \"aws_kms_alias\" \"gh_logs\"",
      "resource \"aws_s3_bucket_server_side_encryption_configuration\" \"gh_logs\"",
      "resource \"aws_s3_bucket_public_access_block\" \"gh_logs\"",
      "resource \"aws_s3_bucket_lifecycle_configuration\" \"gh_logs\"",
      "resource \"aws_s3_bucket_policy\" \"gh_logs_read\"",
      "resource \"aws_sqs_queue\" \"jobs_dlq\"",
      "resource \"aws_sqs_queue\" \"jobs\"",
      "data \"aws_caller_identity\" \"current\"",
      "data \"aws_region\" \"current\"",
      "data \"aws_iam_policy_document\" \"job_log_archiver\"",
      "data \"aws_iam_policy_document\" \"job_log_dispatcher\"",
      "data \"aws_iam_policy_document\" \"internal_s3_reader_assume_role\"",
      "data \"aws_iam_policy_document\" \"internal_s3_reader_policy_doc\"",
      "output \"s3_bucket_arn\"",
      "output \"internal_s3_reader_role_arn\"",
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
