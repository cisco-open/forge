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
      "region   = local.splunk_ingest_token_region",
      "provider \"aws\"",
      "AWS_PROFILE",
      "working_dir = path.module",
      "./scripts/manage_cloudwatch_metric_stream_tags.sh apply",
      "./scripts/manage_cloudwatch_metric_stream_tags.sh remove",
      "filesha256(\"$${path.module}/scripts/manage_cloudwatch_metric_stream_tags.sh\")",
      "sha256(jsonencode(local.all_security_tags))",
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
