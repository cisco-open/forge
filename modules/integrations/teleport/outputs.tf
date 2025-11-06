output "teleport_role_arn" {
  description = "ARN of the IAM role created for Teleport access to the EKS cluster."
  value       = aws_iam_role.teleport_role.arn
}

output "teleport_tenant_groups" {
  description = "Map of tenant name to Kubernetes group name used in aws-auth (teleport-<tenant>)."
  value       = { for t in var.tenants : t => "teleport-${t}" }
}

output "teleport_cluster_name" {
  description = "EKS cluster name used by the Teleport integration."
  value       = var.teleport_config.cluster_name
}

output "teleport_account_id" {
  description = "AWS account ID where Teleport role and resources are created."
  value       = data.aws_caller_identity.current.account_id
}
