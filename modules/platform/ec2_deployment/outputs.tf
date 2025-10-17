output "webhook_endpoint" {
  value = module.runners.webhook.endpoint
}

output "ec2_runners_arn_map" {
  value = {
    for runner_key, runner in module.runners.runners_map : runner_key => runner.role_runner.arn
  }
}

output "ec2_runners_ami_name_map" {
  value = {
    for runner_key, runner in module.runners.runners_map : runner_key => data.aws_ami.runner_ami[runner_key].name
  }
}

output "subnet_cidr_blocks" {
  value = { for id, subnet in data.aws_subnet.runner_subnet : id => subnet.cidr_block }
}

output "event_bus_name" {
  value = module.runners.webhook.eventbridge.event_bus.name
}
