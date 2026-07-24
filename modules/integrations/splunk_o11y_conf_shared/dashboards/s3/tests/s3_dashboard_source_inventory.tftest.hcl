run "s3_dashboard_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_dashboard\" \"s3\"",
      "Forge Tenant - S3",
      "resource \"terraform_data\" \"dashboard_parent\"",
      "filter('namespace', 'AWS/S3')",
      "BucketSizeBytes",
      "NumberOfObjects",
      "__forge_tenant_scope_not_configured__",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Tenant S3 dashboard source inventory is incomplete: ${join(", ", output.missing_expected_literals)}"
  }
}
