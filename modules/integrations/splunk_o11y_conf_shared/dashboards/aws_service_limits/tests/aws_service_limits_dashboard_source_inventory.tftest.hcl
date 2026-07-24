run "aws_service_limits_dashboard_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_dashboard\" \"aws_service_limits\"",
      "Forge Control Plane - AWS Service Limits",
      "resource \"terraform_data\" \"dashboard_parent\"",
      "filter('namespace', 'AWS/TrustedAdvisor')",
      "data('ServiceLimitUsage'",
      "service_name = \"EC2\"",
      "service_name = \"VPC\"",
      "service_name = \"IAM\"",
      ".mean(over='1d').scale(100)",
      "__forge_aws_account_scope_not_configured__",
      "__forge_aws_region_scope_not_configured__",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "AWS service-limits dashboard source inventory is incomplete: ${join(", ", output.missing_expected_literals)}"
  }
}
