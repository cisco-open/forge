locals {
  runner_iam_role_managed_policy_arns = concat(
    # If the policy exists, include it, otherwise skip it
    length(var.tenant.iam_roles_to_assume) > 0 ? [aws_iam_policy.role_assumption_for_forge_runners[0].arn] : [],
    [
      aws_iam_policy.ecr_access_for_ec2_instances.arn,
      module.github_global_lock.dynamodb_policy_arn,
    ]
  )

  github_app_installation = "${var.ghes_url == "" ? "https://github.com" : var.ghes_url}/apps/${data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_name"].secret_string}/installations/${data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_installation_id"].secret_string}"
  github_api              = var.ghes_url == "" ? "https://api.github.com" : "https://api.${replace(var.ghes_url, "https://", "")}"
}
