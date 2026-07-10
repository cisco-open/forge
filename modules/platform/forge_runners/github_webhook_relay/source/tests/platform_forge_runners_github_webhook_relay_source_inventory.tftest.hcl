run "platform_forge_runners_github_webhook_relay_source_contract" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"validate_signature_lambda\"",
      "resource \"aws_cloudwatch_log_group\" \"validate_signature_lambda\"",
      "resource \"aws_apigatewayv2_api\" \"webhook\"",
      "resource \"aws_apigatewayv2_integration\" \"lambda\"",
      "resource \"aws_apigatewayv2_route\" \"post_hook\"",
      "resource \"aws_apigatewayv2_stage\" \"default\"",
      "resource \"aws_lambda_permission\" \"apigw_invoke\"",
      "resource \"aws_cloudwatch_event_bus\" \"source\"",
      "resource \"aws_cloudwatch_log_delivery_source\" \"info_logs\"",
      "resource \"aws_cloudwatch_log_delivery_source\" \"error_logs\"",
      "resource \"aws_cloudwatch_log_group\" \"event_bus_logs\"",
      "resource \"aws_cloudwatch_log_resource_policy\" \"source\"",
      "resource \"aws_cloudwatch_log_delivery_destination\" \"cwlogs\"",
      "resource \"aws_cloudwatch_log_delivery\" \"cwlogs_info_logs\"",
      "resource \"aws_cloudwatch_log_delivery\" \"cwlogs_error_logs\"",
      "resource \"aws_iam_role\" \"events_forward\"",
      "resource \"aws_iam_role_policy\" \"events_forward_put\"",
      "resource \"aws_cloudwatch_event_rule\" \"forward\"",
      "resource \"aws_cloudwatch_event_target\" \"dest\"",
      "data \"aws_iam_policy_document\" \"validate_signature_lambda\"",
      "data \"aws_caller_identity\" \"current\"",
      "data \"aws_iam_policy_document\" \"cwlogs\"",
      "data \"aws_iam_policy_document\" \"events_forward_assume_role\"",
      "data \"aws_iam_policy_document\" \"events_forward_permissions\"",
      "output \"webhook_endpoint\"",
      "output \"source_event_bus_name\"",
      "output \"source_event_bus_arn\"",
      "output \"event_source\"",
    ]
    forbidden_literals = [
      "Principal = \"*\"",
      "WEBHOOK_SECRET = \"\"",
      "actions = [\"*\"]",
      "resources = [\"*\"]",
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

  assert {
    condition     = length(output.present_forbidden_literals) == 0
    error_message = "Module contract includes forbidden literals: ${join(", ", output.present_forbidden_literals)}"
  }
}
