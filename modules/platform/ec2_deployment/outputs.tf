output "webhook_endpoint" {
  value       = module.runners.webhook.endpoint
  description = "Public HTTPS endpoint URL for the GitHub Actions webhook relay."
}

output "ec2_runners_arn_map" {
  value = {
    for runner_key, runner in module.runners.runners_map : runner_key => runner.role_runner.arn
  }
  description = "Map of EC2 runner keys to their IAM role ARNs."
}

output "ec2_runners_ami_name_map" {
  value = {
    for runner_key, runner in module.runners.runners_map : runner_key => data.aws_ami.runner_ami[runner_key].name
  }
  description = "Map of EC2 runner keys to the AMI names used for each runner."
}

output "subnet_cidr_blocks" {
  value       = { for id, subnet in data.aws_subnet.runner_subnet : id => subnet.cidr_block }
  description = "Map of EC2 runner subnet IDs to their CIDR blocks."
}

output "event_bus_name" {
  value       = module.runners.webhook.eventbridge.event_bus.name
  description = "Name of the EventBridge event bus used by the webhook relay."
}
