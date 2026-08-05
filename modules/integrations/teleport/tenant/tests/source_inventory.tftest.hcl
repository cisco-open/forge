run "integrations_teleport_tenant_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"kubernetes_cluster_role_v1\" \"impersonate\"",
      "resource \"kubernetes_cluster_role_v1\" \"pods\"",
      "resource \"kubernetes_cluster_role_binding_v1\" \"impersonate\"",
      "resource \"kubernetes_role_binding_v1\" \"pods\"",
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
