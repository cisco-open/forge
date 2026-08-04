run "integrations_splunk_cloud_data_manager_common_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"aws_iam_role\" \"splunk_dm_read_only\"",
      "resource \"aws_iam_role_policy\" \"splunk_dm_policy_attachment\"",
      "data \"aws_caller_identity\" \"current\"",
      "data \"aws_iam_policy_document\" \"splunk_dm_policy\"",
      "data \"aws_secretsmanager_secret\" \"secrets\"",
      "data \"aws_secretsmanager_secret_version\" \"secrets\"",
      "data \"external\" \"splunk_data\"",
      "data \"external\" \"config\"",
      "\"python3\"",
      "\"$${path.module}/scripts/splunk_data_manager.py\"",
      "\"authenticate\"",
      "\"config\"",
      "username     = local.splunk_cloud_username",
      "password     = local.splunk_cloud_password",
      "splunkweb_csrf_token_8443 = data.external.splunk_data.result[\"splunkweb_csrf_token_8443\"]",
      "splunkd_8443              = data.external.splunk_data.result[\"splunkd_8443\"]",
      "awselb                    = data.external.splunk_data.result[\"awselb\"]",
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
