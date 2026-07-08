run "platform_ec2_deployment_ec2_update_runner_ssm_ami_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"ec2_update_runner_ssm_ami_lambda\"",
      "resource \"aws_cloudwatch_log_group\" \"ec2_update_runner_ssm_ami_lambda\"",
      "resource \"aws_cloudwatch_event_rule\" \"ec2_update_runner_ssm_ami_lambda\"",
      "resource \"aws_cloudwatch_event_target\" \"ec2_update_runner_ssm_ami_lambda\"",
      "resource \"aws_lambda_permission\" \"ec2_update_runner_ssm_ami_lambda\"",
      "data \"aws_iam_policy_document\" \"ec2_update_runner_ssm_ami_lambda\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Module contract is missing expected literals: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count > 0
    error_message = "Module contract must pin at least one module-specific literal."
  }
}
