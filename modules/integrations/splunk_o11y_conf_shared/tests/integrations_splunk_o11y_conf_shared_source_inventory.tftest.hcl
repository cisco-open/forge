run "integrations_splunk_o11y_conf_shared_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"dashboard_runner_ec2\"",
      "module \"dashboard_runner_k8s\"",
      "module \"dashboard_k8s_control_plane\"",
      "module \"dashboard_lambda\"",
      "module \"dashboard_lambda_control_plane\"",
      "module \"dashboard_kinesis_control_plane\"",
      "module \"dashboard_dependency_probes\"",
      "module \"dashboard_aws_regional_health\"",
      "module \"dashboard_sqs\"",
      "module \"dashboard_sqs_control_plane\"",
      "module \"dashboard_s3\"",
      "module \"dashboard_s3_control_plane\"",
      "module \"dashboard_aws_service_limits\"",
      "module \"dashboard_dynamodb\"",
      "module \"dashboard_ebs\"",
      "module \"dashboard_forge_impact\"",
      "module \"dashboard_opencost\"",
      "module \"dashboard_billing\"",
      "module \"detector_k8s\"",
      "module \"detector_dependency_probes\"",
      "module \"detector_aws_regional_health\"",
      "module \"detector_ec2_runner_health\"",
      "failure_duration                   = \"10m\"",
      "no_data_duration                   = \"15m\"",
      "no_data_fill_duration              = \"4h\"",
      "rate_limit_duration                = \"10m\"",
      "rate_limit_remaining_pct_threshold = 10",
      "tenant_names      = var.dashboard_variables.dependency_probes.tenant_names",
      "dynamic_variables = var.dashboard_variables.dependency_probes.dynamic_variables",
      "dynamic_variables = var.dashboard_variables.aws_regional_health.dynamic_variables",
      "dynamic_variables = var.dashboard_variables.lambda_control_plane.dynamic_variables",
      "detector_id       = module.detector_aws_regional_health.control_plane_detector_id",
      "dynamic_variables = var.dashboard_variables.kinesis_control_plane.dynamic_variables",
      "dynamic_variables = var.dashboard_variables.sqs_control_plane.dynamic_variables",
      "Forge Impact and tenant health detectors must use the same tenant_names.",
      "Every Kubernetes and EC2 runner tenant must have a tenant health detector.",
      "tenant_names      = var.dashboard_variables.s3.tenant_names",
      "dynamic_variables = var.dashboard_variables.s3.dynamic_variables",
      "dynamic_variables = var.dashboard_variables.s3_control_plane.dynamic_variables",
      "dynamic_variables = var.dashboard_variables.aws_service_limits.dynamic_variables",
      "tenant_names      = var.dashboard_variables.forge_impact.tenant_names",
      "dynamic_variables = var.dashboard_variables.forge_impact.dynamic_variables",
      "resource \"signalfx_dashboard_group\" \"forgecicd\"",
      "data \"aws_secretsmanager_secret\" \"secrets\"",
      "data \"aws_secretsmanager_secret_version\" \"secrets\"",
      "provider \"aws\"",
      "provider \"signalfx\"",
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
