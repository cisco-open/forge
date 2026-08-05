run "helpers_dedicated_mac_hosts_source_inventory" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"aws_ec2_host\" \"mac_dedicated_host\"",
      "resource \"aws_resourcegroups_group\" \"mac_host_group\"",
      "resource \"aws_resourcegroups_resource\" \"mac_host_membership\"",
      "resource \"aws_licensemanager_license_configuration\" \"mac_dedicated_host_license_configuration\"",
      "provider \"aws\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 5
    error_message = "Source inventory must keep 5 module-specific Terraform blocks pinned."
  }
}
