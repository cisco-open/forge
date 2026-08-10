run "integrations_splunk_cloud_data_manager_log_group_reconciler_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"log_group_reconciler\"",
      "source  = \"terraform-aws-modules/lambda/aws\"",
      "version = \"8.8.0\"",
      "region        = var.region",
      "cloudwatch_logs_retention_in_days = 3",
      "data \"aws_iam_policy_document\" \"log_group_reconciler\"",
      "resource \"aws_cloudwatch_event_rule\" \"lambda_delete\"",
      "resource \"aws_cloudwatch_event_target\" \"lambda_delete\"",
      "resource \"aws_lambda_permission\" \"lambda_delete\"",
      "cloudformation:ListStackResources",
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:TagResource",
      "DeleteFunction20150331",
      "errorCode   = [{ exists = false }]",
      "EXPECTED_ACCOUNT_ID",
      "EXPECTED_PARTITION",
      "EXPECTED_REGION",
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
