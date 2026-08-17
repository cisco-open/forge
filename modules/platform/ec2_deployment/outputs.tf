output "webhook_endpoint" {
  value       = module.runners.webhook.endpoint
  description = "Public HTTPS endpoint URL for the GitHub Actions webhook relay."
}

output "ec2_runners_arn_map" {
  value = {
    for runner_key in keys(local.ec2_runner_configs) : runner_key => coalesce(
      try(module.runners.runners_map_v2[runner_key].runner.role.arn, null),
      try(local.ec2_runner_configs[runner_key].runner.iam.role.arn, null),
    )
  }
  description = "Map of EC2 runner keys to their IAM role ARNs."
}

output "runners_arn_map" {
  value = {
    for runner_key, runner in module.runners.runners_map_v2 : runner_key => coalesce(
      try(runner.runner.role.arn, null),
      try(runner.provider.aws.microvm.execution_role_arn, null),
      try(local.runner_configs[runner_key].runner.iam.role.arn, null),
    )
  }
  description = "Map of runner keys to their resolved EC2 or Lambda MicroVM execution-role ARNs."
}

output "ec2_runners_ami_name_map" {
  value = {
    for runner_key in keys(local.ec2_runner_configs) : runner_key => data.aws_ami.runner_ami[runner_key].name
  }
  description = "Map of EC2 runner keys to the AMI names used for each runner."
}

output "ec2_runners_labels_map" {
  value = {
    for runner_key in keys(local.ec2_runner_configs) : runner_key => local.runner_labels[runner_key]
  }
  description = "Map of EC2 runner keys to their base and extra GitHub labels."
}

output "runners_labels_map" {
  value       = local.runner_labels
  description = "Map of runner keys to their base and extra GitHub labels."
}

output "microvm_runners_arn_map" {
  value = {
    for runner_key in keys(local.microvm_runner_configs) :
    runner_key => module.runners.runners_map_v2[runner_key].provider.aws.microvm.execution_role_arn
  }
  description = "Map of Lambda MicroVM runner keys to their execution-role ARNs."
}

output "microvm_runners_labels_map" {
  value = {
    for runner_key in keys(local.microvm_runner_configs) :
    runner_key => local.runner_labels[runner_key]
  }
  description = "Map of Lambda MicroVM runner keys to their base and extra GitHub labels."
}

output "microvm_runners_map" {
  value = {
    for runner_key in keys(local.microvm_runner_configs) :
    runner_key => module.runners.runners_map_v2[runner_key].provider.aws.microvm
  }
  description = "Map of Lambda MicroVM runner keys to their provider-owned image and execution-role outputs."
}

output "subnet_cidr_blocks" {
  value       = { for id, subnet in data.aws_subnet.runner_subnet : id => subnet.cidr_block }
  description = "Map of EC2 runner subnet IDs to their CIDR blocks."
}

output "event_bus_name" {
  value       = module.runners.webhook.eventbridge.event_bus.name
  description = "Name of the EventBridge event bus used by the webhook relay."
}
