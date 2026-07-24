run "helpers_aws_config_recording_source_inventory" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"aws_config_configuration_recorder\" \"this\"",
      "resource \"aws_config_delivery_channel\" \"this\"",
      "resource \"aws_config_configuration_recorder_status\" \"this\"",
      "resource \"aws_iam_role\" \"config\"",
      "var.recorded_resource_types",
      "provider \"aws\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 6
    error_message = "Source inventory must keep 6 AWS Config Terraform blocks and literals pinned."
  }
}
