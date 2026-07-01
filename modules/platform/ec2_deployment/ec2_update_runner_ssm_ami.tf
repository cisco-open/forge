data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  runner_ami_ssm_parameter_names = {
    for key in keys(var.runner_configs.runner_specs) :
    key => "/github-action-runners/${var.runner_configs.prefix}/${key}/runners/config/ami_id"
  }

  runner_ami_ssm_parameter_arns = {
    for key, name in local.runner_ami_ssm_parameter_names :
    key => "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${name}"
  }
}

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
      resource_ssm_id = local.runner_ami_ssm_parameter_arns[key]
      ssm_id          = local.runner_ami_ssm_parameter_names[key]
      ami_filter      = var.runner_configs.runner_specs[key].ami_filter
      ami_owners      = var.runner_configs.runner_specs[key].ami_owners
    }
  }

}
