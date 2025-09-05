data "aws_ssm_parameter" "ami_id" {
  for_each = {
    for runner_key, runner in module.runners.runners_map :
    runner_key => split("parameter", runner.launch_template_ami_id)[1]
  }

  name            = each.value
  with_decryption = true
  depends_on      = [module.runners]
}

data "aws_ami" "runner_ami" {
  for_each    = { for runner_key, runner in module.runners.runners_map : runner_key => runner.launch_template_ami_id }
  most_recent = false
  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.ami_id[each.key].value]
  }
  depends_on = [module.runners]
}
