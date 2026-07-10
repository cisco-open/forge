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
      "resource \"aws_iam_policy\" \"role_assumption_for_forge_runners\"",
      "resource \"aws_iam_policy\" \"ecr_access_for_ec2_instances\"",
      "resource \"aws_servicecatalogappregistry_application\" \"forge\"",
      "resource \"aws_ssm_parameter\" \"github_app_key\"",
      "resource \"aws_ssm_parameter\" \"github_app_id\"",
      "resource \"aws_ssm_parameter\" \"github_app_client_id\"",
      "resource \"aws_ssm_parameter\" \"github_app_installation_id\"",
      "resource \"aws_ssm_parameter\" \"github_app_name\"",
      "resource \"aws_ssm_parameter\" \"github_app_webhook_secret\"",
      "resource \"time_rotating\" \"every_30_days\"",
      "resource \"random_password\" \"github_app_webhook_secret\"",
      "resource \"null_resource\" \"update_github_app_webhook\"",
      "data \"aws_caller_identity\" \"current\"",
      "data \"aws_region\" \"current\"",
      "data \"aws_iam_policy_document\" \"role_assumption_for_forge_runners\"",
      "data \"aws_iam_policy_document\" \"ecr_access_for_ec2_instances\"",
      "data \"aws_ssm_parameter\" \"github_app_key\"",
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
