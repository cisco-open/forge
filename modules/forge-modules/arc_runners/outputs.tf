output "arc_runners_arn_map" {
  value = {
    for runner_key, runner in module.arc.runners_map : runner_key => runner.runner_role_arn
  }
}

output "subnet_cidr_blocks" {
  value = module.arc.subnet_cidr_blocks
}
