run "platform_arc_scale_set_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"kubernetes_config_map_v1\" \"hook_extension\"",
      "resource \"kubernetes_config_map_v1\" \"hook_pre_post_job\"",
      "resource \"helm_release\" \"gha_runner_scale_set\"",
      "resource \"kubernetes_role_v1\" \"k8s\"",
      "resource \"kubernetes_role_binding_v1\" \"k8s\"",
      "resource \"aws_iam_role\" \"runner_role\"",
      "resource \"aws_iam_role_policy_attachment\" \"runner_role_policy_attachment\"",
      "resource \"kubernetes_service_account_v1\" \"runner_sa\"",
      "resource \"aws_eks_pod_identity_association\" \"eks_pod_identity\"",
      "data \"aws_iam_policy_document\" \"assume_role\"",
      "output \"runner_role_arn\"",
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
