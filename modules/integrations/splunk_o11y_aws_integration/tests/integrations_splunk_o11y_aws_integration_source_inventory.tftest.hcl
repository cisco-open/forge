run "integrations_splunk_o11y_aws_integration_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"aws_cloudformation_stack\" \"splunk_integration\"",
      "resource \"terraform_data\" \"cloudwatch_metric_stream_tags\"",
      "data \"aws_secretsmanager_secret\" \"secrets\"",
      "data \"aws_secretsmanager_secret_version\" \"secrets\"",
      "provider \"aws\"",
      "AWS_PROFILE",
      "aws cloudwatch list-metric-streams",
      "aws cloudwatch tag-resource",
      "aws cloudwatch untag-resource",
      "starts_with(Name, '$STREAM_NAME_PREFIX')",
      "Expected exactly one CloudWatch Metric Stream",
      "sha256(jsonencode(local.all_security_tags))",
      "ResourceNotFoundException",
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
