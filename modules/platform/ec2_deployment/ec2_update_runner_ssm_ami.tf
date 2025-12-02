module "ec2_update_runner_ssm_ami" {
  source = "./ec2_update_runner_ssm_ami"

  providers = {
    aws = aws
  }

  prefix                    = var.runner_configs.prefix
  logging_retention_in_days = var.runner_configs.logging_retention_in_days
  log_level                 = var.runner_configs.log_level
  tags                      = var.tenant_configs.tags

  runner_ami_map = {
    for key in keys(var.runner_configs.runner_specs) :
    key => {
      resource_ssm_id = replace(module.runners.runners_map[key].launch_template_ami_id, "resolve:ssm:", "")
      ssm_id          = split("parameter", module.runners.runners_map[key].launch_template_ami_id)[1]
      ami_filter      = var.runner_configs.runner_specs[key].ami_filter
      ami_owners      = var.runner_configs.runner_specs[key].ami_owners
    }
  }

}
