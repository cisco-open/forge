run "platform_forge_runners_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"arc_runners\"",
      "module \"ec2_runners\"",
      "module \"forge_trust_validator\"",
      "module \"github_actions_job_logs\"",
      "module \"github_app_runner_group\"",
      "module \"github_global_lock\"",
      "module \"github_webhook_relay\"",
      "module \"redrive_deadletter\"",
      "resource \"random_id\" \"random\"",
      "runner_specs = var.ec2_deployment_specs.runner_specs",
      "lambda_artifacts                    = var.ec2_deployment_specs.lambda_artifacts",
      "runner = object({",
      "orchestration_provider = object({",
      "webhook = optional(object({",
      "boot_time_in_minutes = optional(number, null)",
      "ephemeral            = optional(bool, null)",
      "jit_config_enabled   = optional(bool, null)",
      "maximum_count        = optional(number, null)",
      "lambda = optional(object({",
      "queue = optional(object({",
      "visibility_timeout_seconds     = optional(number, null)",
      "scale = optional(object({",
      "up = optional(object({",
      "down = optional(object({",
      "pool = optional(object({",
      "job_retry = optional(object({",
      "artifact = optional(object({",
      "compute_provider = object({",
      "aws = optional(object({",
      "ec2 = optional(object({",
      "microvm = optional(object({",
      "image_arn                   = optional(string, null)",
      "matcherConfig = object({",
      "scale_errors = optional(list(string), [",
      "try(module.ec2_runners[0].runners_arn_map, {}),",
      "description = \"Combined runners output (EC2 + Lambda MicroVM + ARC)\"",
      "microvm = {",
      "runners_arn_map = try(module.ec2_runners[0].microvm_runners_arn_map, {})",
      "runners         = try(module.ec2_runners[0].microvm_runners_map, {})",
      "runner_labels   = try(module.ec2_runners[0].microvm_runners_labels_map, {})",
      "resource \"aws_iam_policy\" \"role_assumption_for_forge_runners\"",
      "resource \"aws_iam_policy\" \"ecr_access_for_ec2_instances\"",
      "resource \"aws_servicecatalogappregistry_application\" \"forge\"",
      "resource \"aws_ssm_parameter\" \"github_app_key\"",
      "resource \"aws_ssm_parameter\" \"github_app_id\"",
      "resource \"aws_ssm_parameter\" \"github_app_client_id\"",
      "resource \"aws_ssm_parameter\" \"github_app_installation_id\"",
      "resource \"aws_ssm_parameter\" \"github_ghes_url\"",
      "resource \"aws_ssm_parameter\" \"github_ghes_org\"",
      "name        = \"/forge/$${var.deployment_config.deployment_prefix}/github_ghes_url\"",
      "value       = var.deployment_config.github.ghes_url == \"\" ? \"https://github.com\" : var.deployment_config.github.ghes_url",
      "name        = \"/forge/$${var.deployment_config.deployment_prefix}/github_ghes_org\"",
      "value       = var.deployment_config.github.ghes_org",
      "tags = local.all_security_tags",
      "tags = merge(",
      "resource \"aws_ssm_parameter\" \"github_app_name\"",
      "resource \"aws_ssm_parameter\" \"github_app_webhook_secret\"",
      "resource \"time_rotating\" \"every_30_days\"",
      "resource \"random_password\" \"github_app_webhook_secret\"",
      "resource \"null_resource\" \"update_github_app_webhook\"",
      "data \"aws_caller_identity\" \"current\"",
      "data \"aws_partition\" \"current\"",
      "data \"aws_region\" \"current\"",
      "data \"aws_iam_policy_document\" \"role_assumption_for_forge_runners\"",
      "data \"aws_iam_policy_document\" \"ecr_access_for_ec2_instances\"",
      "data \"aws_ssm_parameter\" \"github_app_key\"",
      "iam_policy_arn_prefix = \"arn:$${data.aws_partition.current.partition}:iam::$${data.aws_caller_identity.current.account_id}:policy\"",
      "\"$${local.iam_policy_arn_prefix}$${aws_iam_policy.role_assumption_for_forge_runners[0].path}$${aws_iam_policy.role_assumption_for_forge_runners[0].name}\"",
      "\"$${local.iam_policy_arn_prefix}$${aws_iam_policy.ecr_access_for_ec2_instances.path}$${aws_iam_policy.ecr_access_for_ec2_instances.name}\"",
      "output \"forge_core\"",
      "output \"forge_runners\"",
      "output \"forge_webhook_relay\"",
      "output \"forge_github_actions_job_logs\"",
      "output \"forge_github_app\"",
      "provider \"aws\"",
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
