run "integrations_teleport_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"tenant\"",
      "resource \"kubernetes_config_map_v1\" \"aws_auth_teleport\"",
      "resource \"aws_iam_role\" \"teleport_role\"",
      "resource \"aws_iam_policy\" \"eks_policy\"",
      "resource \"aws_iam_role_policy_attachment\" \"attach_eks_policy\"",
      "data \"aws_eks_cluster\" \"cluster\"",
      "data \"aws_eks_cluster_auth\" \"cluster\"",
      "data \"aws_caller_identity\" \"current\"",
      "data \"aws_iam_policy_document\" \"eks_policy\"",
      "data \"aws_iam_policy_document\" \"trust_policy\"",
      "output \"teleport_role_arn\"",
      "output \"teleport_tenant_groups\"",
      "output \"teleport_cluster_name\"",
      "output \"teleport_account_id\"",
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
