run "platform_ec2_deployment_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"ec2_update_runner_ssm_ami\"",
      "module \"ec2_update_runner_tags\"",
      "module \"runners\"",
      "source = \"git::https://github.com/github-aws-runners/terraform-aws-github-runner.git//modules/multi-runner?ref=fix-multi-runner-v2-routing\"",
      "experimental = {",
      "multi_runner_config = {}",
      "experimental        = local.experimental_config",
      "experimental_config = {",
      "app = var.runner_configs.github_app",
      "kms_key_id = aws_kms_key.github.arn",
      "multi_runner_config = local.multi_runner_config",
      "resource \"aws_cloudwatch_log_group\" \"webhook_api_gateway_access\"",
      "resource \"aws_kms_key\" \"github\"",
      "resource \"aws_kms_alias\" \"github\"",
      "resource \"aws_ssm_parameter\" \"hook_job_started\"",
      "resource \"aws_ssm_parameter\" \"hook_job_completed\"",
      "runner_ssm_paths = {",
      "root = \"$${trimsuffix(coalesce(runner_config.ssm.paths.root, \"/github-action-runners/$${var.runner_configs.prefix}\"), \"/\")}/$${key}\"",
      "runner_ami_ssm_parameter_names = {",
      "key => \"$${paths.root}/$${paths.config}/ami_id\"",
      "resource \"aws_iam_policy\" \"runner_hooks_ssm_read\"",
      "resource \"aws_iam_policy\" \"ec2_tags\"",
      "resource \"aws_security_group\" \"gh_runner_lambda_egress\"",
      "data \"aws_ssm_parameter\" \"ami_id\"",
      "data \"aws_ami\" \"runner_ami\"",
      "data \"aws_caller_identity\" \"current\"",
      "data \"aws_partition\" \"current\"",
      "data \"aws_subnet\" \"runner_subnet\"",
      "data \"external\" \"download_lambdas\"",
      "data \"aws_iam_policy_document\" \"runner_hooks_ssm_read\"",
      "data \"aws_iam_policy_document\" \"ec2_tags\"",
      "output \"webhook_endpoint\"",
      "output \"ec2_runners_arn_map\"",
      "output \"ec2_runners_ami_name_map\"",
      "output \"ec2_runners_labels_map\"",
      "output \"subnet_cidr_blocks\"",
      "output \"event_bus_name\"",
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
