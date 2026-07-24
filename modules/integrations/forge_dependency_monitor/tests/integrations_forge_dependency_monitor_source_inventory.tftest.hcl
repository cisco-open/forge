run "integrations_forge_dependency_monitor_source_inventory" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"dependency_monitor\"",
      "resource \"aws_cloudwatch_log_group\" \"dependency_monitor\"",
      "resource \"aws_cloudwatch_event_rule\" \"dependency_monitor\"",
      "resource \"aws_cloudwatch_event_target\" \"dependency_monitor\"",
      "resource \"aws_lambda_permission\" \"eventbridge_invoke\"",
      "data \"aws_iam_policy_document\" \"dependency_monitor\"",
      "data \"aws_secretsmanager_secret\" \"secrets\"",
      "data \"aws_secretsmanager_secret_version\" \"secrets\"",
      "data \"aws_caller_identity\" \"current\"",
      "data \"aws_region\" \"current\"",
      "ssm:DescribeParameters",
      "parameter/forge/*/tenant_name",
      "GITHUB_API_VERSION",
      "SPLUNK_HEC_URL",
      "SPLUNK_METRICS_URL",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Module contract is missing expected literals: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 15
    error_message = "Source inventory count must remain pinned."
  }
}
