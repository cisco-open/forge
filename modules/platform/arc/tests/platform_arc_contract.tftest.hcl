run "platform_arc_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"controller\"",
      "module \"scale_sets\"",
      "resource \"null_resource\" \"apply_ec2_node_class\"",
      "resource \"null_resource\" \"apply_node_pool\"",
      "resource \"kubernetes_manifest\" \"storage_class\"",
      "data \"aws_eks_cluster\" \"cluster\"",
      "data \"aws_eks_cluster_auth\" \"cluster\"",
      "data \"aws_subnet\" \"eks_subnets\"",
      "data \"aws_iam_openid_connect_provider\" \"cluster\"",
      "data \"external\" \"update_kubeconfig\"",
      "data \"external\" \"karpenter_ec2nodeclass\"",
      "output \"runners_map\"",
      "output \"subnet_cidr_blocks\"",
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
