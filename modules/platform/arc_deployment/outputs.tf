output "arc_runners_arn_map" {
  value = {
    for runner_key, runner in module.arc.runners_map : runner_key => runner.runner_role_arn
  }
  description = "Map of ARC runner keys to their IAM role ARNs."
}

output "subnet_cidr_blocks" {
  value       = module.arc.subnet_cidr_blocks
  description = "Map of ARC runner subnet IDs to their CIDR blocks."
}

output "arc_cluster_name" {
  value       = var.runner_configs.arc_cluster_name
  description = "Name of the Kubernetes cluster used for ARC runners."
}
