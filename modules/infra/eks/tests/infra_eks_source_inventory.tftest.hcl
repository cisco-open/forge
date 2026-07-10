run "infra_eks_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"ebs_csi_irsa_role\"",
      "module \"eks\"",
      "module \"karpenter\"",
      "module \"self_managed_node_group\"",
      "resource \"aws_eks_addon\" \"aws_ebs_csi_driver\"",
      "resource \"aws_eks_addon\" \"eks_pod_identity_agent\"",
      "resource \"aws_eks_addon\" \"coredns\"",
      "resource \"null_resource\" \"patch_calico_installation\"",
      "resource \"null_resource\" \"wait_for_cluster\"",
      "resource \"null_resource\" \"karpenter\"",
      "resource \"null_resource\" \"apply_ec2_node_class\"",
      "resource \"null_resource\" \"apply_node_pool\"",
      "data \"aws_eks_addon_version\" \"aws_ebs_csi_driver\"",
      "data \"aws_eks_addon_version\" \"eks_pod_identity_agent\"",
      "data \"aws_eks_addon_version\" \"coredns\"",
      "data \"aws_eks_addon_version\" \"kube_proxy\"",
      "data \"aws_eks_cluster\" \"cluster\"",
      "data \"aws_eks_cluster_auth\" \"cluster\"",
      "data \"external\" \"update_kubeconfig\"",
      "data \"aws_ami\" \"eks_default\"",
      "output \"cluster_endpoint\"",
      "output \"cluster_security_group_id\"",
      "output \"aws_region\"",
      "output \"kubeconfig\"",
      "provider \"aws\"",
      "provider \"kubectl\"",
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
