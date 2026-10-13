moved {
  from = aws_iam_policy.ec2_tags
  to   = aws_iam_policy.ec2_tags[0]
}

moved {
  from = aws_iam_policy.runner_hooks_ssm_read
  to   = aws_iam_policy.runner_hooks_ssm_read[0]
}

moved {
  from = module.ec2_update_runner_ssm_ami
  to   = module.ec2_update_runner_ssm_ami[0]
}

moved {
  from = module.ec2_update_runner_tags
  to   = module.ec2_update_runner_tags[0]
}
