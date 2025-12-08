module "forge_trust_validator" {
  count  = length(var.tenant.iam_roles_to_assume) > 0 ? 1 : 0
  source = "./forge_trust_validator"

  providers = {
    aws = aws
  }

  aws_profile               = var.aws_profile
  prefix                    = var.deployment_config.prefix
  logging_retention_in_days = var.logging_retention_in_days
  log_level                 = var.log_level
  tags                      = local.all_security_tags

  forge_iam_roles = {
    for idx, arn in values(merge(
      try(module.ec2_runners[0].ec2_runners_arn_map, {}),
      try(module.arc_runners.arc_runners_arn_map, {}),
    )) :
    idx => arn
  }
  number_forge_iram_roles = (
    length(var.ec2_runner_specs) +
    length(var.arc_runner_specs)
  )

  tenant_iam_roles = var.tenant.iam_roles_to_assume
}
