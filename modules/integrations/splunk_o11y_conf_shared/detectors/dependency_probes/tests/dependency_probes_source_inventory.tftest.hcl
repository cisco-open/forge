run "dependency_probes_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_detector\" \"tenant_dependency_health\"",
      "for_each = toset(var.tenant_names)",
      "filter('TenantName', '$${each.value}')",
      "filter('CheckName', 'SSMCredentials')",
      "filter('CheckName', 'OrgRunnersApi')",
      "forge.dependency.availability",
      "forge.dependency.rate_limit_remaining_pct",
      "Tenant dependency probe has no data",
      "Tenant GitHub App SSM credentials unavailable",
      "Tenant GitHub API unavailable",
      "Tenant GitHub API rate-limit budget low",
      "Tenant Lambda error rate high",
      "Tenant Lambda throttling",
      "Tenant build queue delayed",
      "Tenant build queue stuck",
      "Tenant DLQ backlog",
      "Tenant Kubernetes pod pending",
      "Tenant Kubernetes pod failed or unknown",
      "Tenant Kubernetes container restarting",
      "Tenant EC2 status check failure",
      "Tenant EBS IOPS limit exceeded",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Detector contract is missing expected literals: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 21
    error_message = "Detector source inventory count must remain pinned."
  }
}
