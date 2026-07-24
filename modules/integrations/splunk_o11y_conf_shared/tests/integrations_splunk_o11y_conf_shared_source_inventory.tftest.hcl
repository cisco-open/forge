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
      "module \"dashboard_sqs\"",
      "module \"dashboard_dynamodb\"",
      "module \"dashboard_ebs\"",
      "module \"dashboard_forge_impact\"",
      "module \"dashboard_opencost\"",
      "module \"dashboard_billing\"",
      "module \"detector_k8s\"",
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

run "splunk_o11y_dashboards_reject_dynamic_plot_names" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path        = "dashboards"
    recursive          = true
    expected_literals  = []
    forbidden_literals = ["display_name = \"{{"]
  }

  assert {
    condition     = length(output.present_forbidden_literals) == 0
    error_message = "Dashboard viz_options.display_name values must be static; identity belongs in dimension fields."
  }
}
