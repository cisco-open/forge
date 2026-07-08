run "integrations_splunk_cloud_data_manager_data_input_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"random_uuid\" \"splunk_input_uuid\"",
      "resource \"null_resource\" \"create_integration\"",
      "resource \"null_resource\" \"delete_integration\"",
      "resource \"aws_s3_object\" \"cloudformation_template\"",
      "data \"external\" \"splunk_dm_version\"",
      "data \"aws_secretsmanager_secret\" \"secrets\"",
      "data \"aws_secretsmanager_secret_version\" \"secrets\"",
      "output \"splunk_integration_name\"",
      "output \"splunk_integration_template_url\"",
      "output \"splunk_integration_tags\"",
      "output \"splunk_integration_tags_all\"",
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
