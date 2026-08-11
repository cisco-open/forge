data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  runner_ami_ssm_parameter_names = {
    for key in keys(local.ec2_runner_configs) :
    key => "/github-action-runners/${var.runner_configs.prefix}/${key}/runners/config/ami_id"
  }

  runner_ami_ssm_parameter_arns = {
    for key, name in local.runner_ami_ssm_parameter_names :
    key => "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${name}"
  }

  ec2_update_runner_ami_map = {
    for key, runner_config in local.ec2_runner_configs :
    key => {
      resource_ssm_id = local.runner_ami_ssm_parameter_arns[key]
      ssm_id          = local.runner_ami_ssm_parameter_names[key]
      ami_filter      = local.ec2_compute_provider[key].ami.filter
      ami_owners      = local.ec2_compute_provider[key].ami.owners
    }
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

  runner_ami_map = local.ec2_update_runner_ami_map

}
