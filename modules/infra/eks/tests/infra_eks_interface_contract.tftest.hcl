run "infra_eks_interface_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "aws_profile",
      "aws_region",
      "cluster_admin_role_arn",
      "cluster_ami_filter",
      "cluster_ami_owners",
      "cluster_endpoint_public_access",
      "cluster_name",
      "cluster_size",
      "cluster_tags",
      "cluster_version",
      "cluster_volume",
      "default_tags",
      "external_access_cidr_blocks",
      "subnet_ids",
      "tags",
      "vpc_id",
    ]
    expected_output_values = [
      "aws_region",
      "cluster_endpoint",
      "cluster_security_group_id",
      "kubeconfig",
    ]
    expected_interface_literals = [
      "variable \"aws_profile\"",
      "type        = string",
      "description = \"AWS profile to use.\"",
      "variable \"aws_region\"",
      "description = \"Default AWS region.\"",
      "variable \"cluster_admin_role_arn\"",
      "description = \"Full ARN of IAM role for EKS cluster admin access.\"",
      "default     = \"\"",
      "variable \"cluster_ami_filter\"",
      "description = \"The AWS account ID that owns the EKS cluster AMI.\"",
      "type        = list(string)",
      "variable \"cluster_ami_owners\"",
      "variable \"cluster_endpoint_public_access\"",
      "description = \"Whether the EKS cluster endpoint is publicly accessible\"",
      "type        = bool",
      "default     = false",
      "variable \"cluster_name\"",
      "description = \"The name of the EKS cluster\"",
      "variable \"cluster_size\"",
      "description = \"The size config of the EKS cluster\"",
      "type = object({",
      "instance_type = string",
      "min_size      = number",
      "max_size      = number",
      "desired_size  = number",
      "variable \"cluster_tags\"",
      "type        = map(string)",
      "description = \"Cluster tags\"",
      "variable \"cluster_version\"",
      "description = \"The version of the EKS cluster\"",
      "variable \"cluster_volume\"",
      "description = \"The volume config of the EKS cluster\"",
      "size       = number",
      "iops       = number",
      "throughput = number",
      "type       = string",
      "variable \"default_tags\"",
      "description = \"A map of tags to apply to resources.\"",
      "variable \"external_access_cidr_blocks\"",
      "description = \"External CIDR Blocks to access k8s api\"",
      "default     = []",
      "variable \"subnet_ids\"",
      "description = \"A list of private subnet IDs for worker nodes\"",
      "variable \"tags\"",
      "variable \"vpc_id\"",
      "description = \"The ID of the VPC\"",
      "output \"aws_region\"",
      "description = \"AWS region.\"",
      "value       = var.aws_region",
      "output \"cluster_endpoint\"",
      "description = \"Endpoint for EKS control plane.\"",
      "value       = module.eks.cluster_endpoint",
      "output \"cluster_security_group_id\"",
      "description = \"Security group ids attached to the cluster control plane.\"",
      "value       = module.eks.cluster_security_group_id",
      "output \"kubeconfig\"",
      "value = data.external.update_kubeconfig.result",
    ]
  }

  assert {
    condition     = length(output.missing_input_variables) == 0
    error_message = "Interface contract is missing input variables: ${join(", ", output.missing_input_variables)}"
  }

  assert {
    condition     = length(output.unexpected_input_variables) == 0
    error_message = "Interface contract has unexpected input variables: ${join(", ", output.unexpected_input_variables)}"
  }

  assert {
    condition     = length(output.missing_output_values) == 0
    error_message = "Interface contract is missing outputs: ${join(", ", output.missing_output_values)}"
  }

  assert {
    condition     = length(output.unexpected_output_values) == 0
    error_message = "Interface contract has unexpected outputs: ${join(", ", output.unexpected_output_values)}"
  }

  assert {
    condition     = length(output.missing_interface_literals) == 0
    error_message = "Interface contract is missing expected variable/output source lines: ${join(", ", output.missing_interface_literals)}"
  }

  assert {
    condition = (
      output.expected_input_variable_count == 16
      && output.expected_output_value_count == 4
      && output.expected_interface_literal_count == 57
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
