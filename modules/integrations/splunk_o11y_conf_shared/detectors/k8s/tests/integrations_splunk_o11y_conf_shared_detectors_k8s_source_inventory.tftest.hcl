run "integrations_splunk_o11y_conf_shared_detectors_k8s_contract" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_detector\" \"k8s_otel_no_data\"",
      "resource \"signalfx_detector\" \"k8s_otel_collector_health\"",
      "resource \"signalfx_detector\" \"k8s_other_namespace_pods_unhealthy\"",
      "resource \"signalfx_detector\" \"k8s_tenant_pods_pending\"",
      "resource \"signalfx_detector\" \"k8s_tenant_pods_failed\"",
      "resource \"signalfx_detector\" \"k8s_tenant_container_restarts\"",
      "resource \"signalfx_detector\" \"k8s_platform_pods_unhealthy\"",
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
