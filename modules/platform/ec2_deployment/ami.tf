data "aws_ssm_parameter" "ami_id" {
  for_each = local.runner_ami_ssm_parameter_names

  name            = each.value
  with_decryption = true
}

data "aws_ami" "runner_ami" {
  for_each    = var.runner_configs.runner_specs
  most_recent = false

  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.ami_id[each.key].value]
  }
}
