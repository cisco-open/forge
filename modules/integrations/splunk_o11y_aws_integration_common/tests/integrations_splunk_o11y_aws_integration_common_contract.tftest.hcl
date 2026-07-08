run "integrations_splunk_o11y_aws_integration_common_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"aws_iam_role\" \"splunk_integration\"",
      "resource \"aws_iam_role_policy\" \"splunk_integration\"",
      "resource \"aws_iam_role_policy\" \"splunk_managed_policy\"",
      "resource \"signalfx_aws_external_integration\" \"integration\"",
      "resource \"signalfx_aws_integration\" \"integration\"",
      "resource \"time_sleep\" \"wait_30_seconds\"",
      "data \"aws_caller_identity\" \"current\"",
      "data \"aws_iam_policy_document\" \"splunk_integration\"",
      "data \"aws_iam_policy_document\" \"splunk_managed_policy\"",
      "data \"aws_iam_policy_document\" \"assume_role_policy\"",
      "data \"aws_secretsmanager_secret\" \"secrets\"",
      "data \"aws_secretsmanager_secret_version\" \"secrets\"",
      "output \"iam_role_splunk_integration\"",
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
