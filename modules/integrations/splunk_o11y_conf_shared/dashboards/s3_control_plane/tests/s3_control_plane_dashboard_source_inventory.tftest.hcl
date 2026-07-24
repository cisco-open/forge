run "s3_control_plane_dashboard_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_dashboard\" \"s3_control_plane\"",
      "Forge Control Plane - S3",
      "resource \"terraform_data\" \"dashboard_parent\"",
      "not filter('aws_tag_TenantName', '*')",
      "filter('namespace', 'AWS/S3')",
      "BucketSizeBytes",
      "NumberOfObjects",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Control-plane S3 dashboard source inventory is incomplete: ${join(", ", output.missing_expected_literals)}"
  }
}
