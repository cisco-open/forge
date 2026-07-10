run "integrations_splunk_stuck_workflow_job_dispatcher_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"dispatcher\"",
      "module \"worker\"",
      "resource \"random_password\" \"webhook_token\"",
      "resource \"aws_apigatewayv2_api\" \"splunk\"",
      "resource \"aws_apigatewayv2_integration\" \"dispatcher\"",
      "resource \"aws_apigatewayv2_route\" \"splunk_webhook\"",
      "resource \"aws_apigatewayv2_stage\" \"default\"",
      "resource \"aws_cloudwatch_log_group\" \"api\"",
      "resource \"aws_lambda_permission\" \"apigw_invoke\"",
      "resource \"aws_dynamodb_table\" \"dedupe\"",
      "resource \"aws_cloudwatch_log_group\" \"dispatcher\"",
      "resource \"aws_cloudwatch_log_group\" \"worker\"",
      "resource \"aws_lambda_event_source_mapping\" \"worker_from_dedupe_stream\"",
      "resource \"splunk_configs_conf\" \"stuck_workflow_job_dispatcher\"",
      "resource \"aws_ssm_parameter\" \"tenant_configs\"",
      "data \"aws_iam_policy_document\" \"dispatcher\"",
      "data \"aws_region\" \"current\"",
      "data \"aws_caller_identity\" \"current\"",
      "data \"aws_iam_policy_document\" \"worker\"",
      "data \"aws_secretsmanager_secret\" \"splunk_cloud_api_token\"",
      "data \"aws_secretsmanager_secret_version\" \"splunk_cloud_api_token\"",
      "output \"api_endpoint\"",
      "output \"splunk_webhook_url\"",
      "output \"receiver_lambda_function_arn\"",
      "output \"api_log_group_name\"",
      "output \"receiver_lambda_log_group_name\"",
      "output \"worker_lambda_function_arn\"",
      "output \"worker_lambda_log_group_name\"",
      "output \"dedupe_table_name\"",
      "output \"saved_search_name\"",
      "provider \"aws\"",
      "provider \"splunk\"",
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
