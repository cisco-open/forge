run "integrations_splunk_opencost_eks_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"helm_release\" \"managed_prometheus\"",
      "resource \"helm_release\" \"opencost\"",
      "data \"aws_eks_cluster\" \"cluster\"",
      "data \"aws_eks_cluster_auth\" \"cluster\"",
      "output \"namespace\"",
      "output \"release_name\"",
      "output \"service_name\"",
      "output \"service_account_name\"",
      "output \"metrics_endpoint\"",
      "output \"metrics_host\"",
      "output \"metrics_port\"",
      "output \"metrics_path\"",
      "output \"prometheus_endpoint\"",
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
