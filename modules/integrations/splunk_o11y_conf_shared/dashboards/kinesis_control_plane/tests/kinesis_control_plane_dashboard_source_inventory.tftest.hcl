run "kinesis_control_plane_dashboard_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_dashboard\" \"kinesis_control_plane\"",
      "Forge Control Plane - Kinesis",
      "resource \"terraform_data\" \"dashboard_parent\"",
      "terraform_data.dashboard_parent,",
      "not filter('aws_tag_TenantName', '*')",
      "filter('namespace', 'AWS/Kinesis')",
      "filter('StreamName', '*')",
      "__forge_aws_account_scope_not_configured__",
      "__forge_aws_region_scope_not_configured__",
      "__forge_product_family_scope_not_configured__",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Kinesis control-plane dashboard source inventory is incomplete: ${join(", ", output.missing_expected_literals)}"
  }
}
