run "arc_runner_operations_dashboard_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_dashboard\" \"arc_runner_operations\"",
      "resource \"signalfx_single_value_chart\" \"active_scale_sets\"",
      "resource \"signalfx_single_value_chart\" \"registered_runners\"",
      "resource \"signalfx_single_value_chart\" \"running_listeners\"",
      "resource \"signalfx_single_value_chart\" \"failed_ephemeral_runners\"",
      "resource \"signalfx_time_chart\" \"controller_state\"",
      "resource \"signalfx_time_chart\" \"runner_supply\"",
      "resource \"signalfx_list_chart\" \"capacity_gap\"",
      "resource \"signalfx_list_chart\" \"runner_utilization\"",
      "resource \"signalfx_time_chart\" \"job_throughput\"",
      "resource \"signalfx_time_chart\" \"completion_outcomes\"",
      "resource \"signalfx_time_chart\" \"success_rate\"",
      "resource \"signalfx_time_chart\" \"startup_latency\"",
      "resource \"signalfx_time_chart\" \"execution_latency\"",
      "resource \"signalfx_list_chart\" \"top_workflows\"",
      "resource \"signalfx_list_chart\" \"slow_workflows\"",
      "resource \"signalfx_list_chart\" \"failure_fingerprints\"",
      "resource \"terraform_data\" \"dashboard_parent\"",
      "gha_started_jobs_total",
      "gha_job_startup_duration_seconds",
      "job_workflow_target",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "ARC dashboard is missing expected operator charts or metric contracts: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 21
    error_message = "ARC dashboard source inventory count must remain pinned."
  }
}
