run "lambda_control_plane_dashboard_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_dashboard\" \"lambda_control_plane\"",
      "Forge Control Plane - Lambdas",
      "resource \"terraform_data\" \"dashboard_parent\"",
      "terraform_data.dashboard_parent,",
      "not filter('aws_tag_TenantName', '*')",
      "__forge_aws_account_scope_not_configured__",
      "__forge_aws_region_scope_not_configured__",
      "__forge_product_family_scope_not_configured__",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Lambda control-plane dashboard source inventory is incomplete: ${join(", ", output.missing_expected_literals)}"
  }
}
