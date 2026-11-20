locals {
  iam_policy_arn_prefix = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy"
  runner_iam_role_managed_policy_arns = concat(
    # If the policy exists, include it, otherwise skip it
    length(var.deployment_config.tenant.iam_roles_to_assume) > 0 ? [
      "${local.iam_policy_arn_prefix}${aws_iam_policy.role_assumption_for_forge_runners[0].path}${aws_iam_policy.role_assumption_for_forge_runners[0].name}"
    ] : [],
    [
      "${local.iam_policy_arn_prefix}${aws_iam_policy.ecr_access_for_ec2_instances.path}${aws_iam_policy.ecr_access_for_ec2_instances.name}",
      module.github_global_lock.dynamodb_policy_arn,
    ]
  )

  github_app_installation = "${var.deployment_config.github.ghes_url == "" ? "https://github.com" : var.deployment_config.github.ghes_url}/apps/${var.deployment_config.github_app.name}/installations/${var.deployment_config.github_app.installation_id}"
  github_api              = var.deployment_config.github.ghes_url == "" ? "https://api.github.com" : "${var.deployment_config.github.ghes_url}/api/v3"
}
