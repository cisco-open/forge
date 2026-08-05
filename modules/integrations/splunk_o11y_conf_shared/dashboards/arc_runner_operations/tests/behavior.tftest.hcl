mock_provider "signalfx" {}

variables {
  dashboard_group = "forge-dashboard-group"
  tenant_names    = ["tenant-b", "tenant-a"]
  dynamic_variables = [
    {
      property               = "k8s.cluster.name"
      alias                  = "Kubernetes cluster"
      description            = "Limit by Kubernetes cluster"
      values                 = []
      value_required         = false
      values_suggested       = ["forge-use1-prod", "forge-euw1-prod"]
      restricted_suggestions = true
    }
  ]
}

run "arc_operator_flow_contract" {
  command = plan

  assert {
    condition = (
      signalfx_single_value_chart.active_scale_sets.name == "Active ARC scale sets"
      && strcontains(signalfx_single_value_chart.active_scale_sets.program_text, "gha_desired_runners")
      && strcontains(signalfx_single_value_chart.active_scale_sets.program_text, "filter('k8s.cluster.name', 'forge-euw1-prod') or filter('k8s.cluster.name', 'forge-use1-prod')")
      && strcontains(signalfx_single_value_chart.active_scale_sets.program_text, "filter('k8s.namespace.name', 'tenant-a') or filter('k8s.namespace.name', 'tenant-b')")
      && strcontains(signalfx_single_value_chart.running_listeners.program_text, "gha_controller_running_listeners")
      && strcontains(signalfx_single_value_chart.failed_ephemeral_runners.program_text, "gha_controller_failed_ephemeral_runners")
      && strcontains(signalfx_time_chart.controller_state.program_text, "gha_controller_pending_ephemeral_runners")
      && strcontains(signalfx_time_chart.controller_state.program_text, "filter('k8s.namespace.name', 'tenant-a') or filter('k8s.namespace.name', 'tenant-b')")
    )
    error_message = "ARC dashboard must begin with cluster-scoped telemetry freshness and controller state."
  }

  assert {
    condition = (
      strcontains(signalfx_time_chart.runner_supply.program_text, "gha_assigned_jobs")
      && strcontains(signalfx_time_chart.runner_supply.program_text, "gha_running_jobs")
      && strcontains(signalfx_time_chart.runner_supply.program_text, "gha_desired_runners")
      && strcontains(signalfx_time_chart.runner_supply.program_text, "gha_registered_runners")
      && strcontains(signalfx_time_chart.runner_supply.program_text, "gha_busy_runners")
      && strcontains(signalfx_time_chart.runner_supply.program_text, "gha_idle_runners")
      && strcontains(signalfx_list_chart.capacity_gap.program_text, "D - R")
      && strcontains(signalfx_list_chart.runner_utilization.program_text, "B / R * 100")
    )
    error_message = "ARC capacity charts must compare assigned and running job pressure with desired, registered, busy, and idle runner state without inventing a severity threshold."
  }

  assert {
    condition = (
      strcontains(signalfx_time_chart.job_throughput.program_text, "gha_started_jobs_total")
      && strcontains(signalfx_time_chart.job_throughput.program_text, "gha_completed_jobs_total")
      && length(regexall("rollup='rate'", signalfx_time_chart.job_throughput.program_text)) == 2
      && strcontains(signalfx_time_chart.job_throughput.program_text, "filter('k8s.namespace.name', 'tenant-a') or filter('k8s.namespace.name', 'tenant-b')")
      && strcontains(signalfx_time_chart.completion_outcomes.program_text, "job_result")
      && strcontains(signalfx_time_chart.success_rate.program_text, "filter('job_result', 'success')")
    )
    error_message = "ARC throughput and outcome charts must use reset-safe counter rates and retain the GitHub result dimension."
  }

  assert {
    condition = (
      strcontains(signalfx_time_chart.startup_latency.program_text, "histogram('gha_job_startup_duration_seconds'")
      && strcontains(signalfx_time_chart.execution_latency.program_text, "histogram('gha_job_execution_duration_seconds'")
      && length(regexall("percentile\\(pct=", signalfx_time_chart.startup_latency.program_text)) == 3
      && length(regexall("percentile\\(pct=", signalfx_time_chart.execution_latency.program_text)) == 3
      && strcontains(signalfx_time_chart.startup_latency.program_text, "filter('k8s.namespace.name', 'tenant-a') or filter('k8s.namespace.name', 'tenant-b')")
      && strcontains(signalfx_list_chart.slow_workflows.program_text, "job_workflow_name")
    )
    error_message = "ARC latency charts must use native P50, P90, and P99 histograms and retain workflow drilldown."
  }

  assert {
    condition = alltrue([
      for property in [
        "organization",
        "repository",
        "job_workflow_name",
        "job_name",
        "event_name",
        "job_result",
        "job_workflow_ref",
        "job_workflow_target",
        ] : contains([
          for field in signalfx_list_chart.failure_fingerprints.legend_options_fields :
          field.property if field.enabled
      ], property)
    ])
    error_message = "Non-success fingerprints must retain the high-cardinality dimensions needed to open the matching GitHub run and logs."
  }
}

run "arc_dashboard_layout_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.arc_runner_operations.name == "Forge ARC Runner Operations"
      && signalfx_dashboard.arc_runner_operations.dashboard_group == "forge-dashboard-group"
      && signalfx_dashboard.arc_runner_operations.time_range == "-1h"
      && signalfx_dashboard.arc_runner_operations.variable[0].property == "k8s.namespace.name"
      && signalfx_dashboard.arc_runner_operations.variable[0].values_suggested == toset(["tenant-a", "tenant-b"])
      && signalfx_dashboard.arc_runner_operations.variable[0].restricted_suggestions
      && length(signalfx_dashboard.arc_runner_operations.chart) == 16
      && contains([for chart in signalfx_dashboard.arc_runner_operations.chart : chart.chart_id], signalfx_single_value_chart.active_scale_sets.id)
      && contains([for chart in signalfx_dashboard.arc_runner_operations.chart : chart.chart_id], signalfx_time_chart.startup_latency.id)
      && contains([for chart in signalfx_dashboard.arc_runner_operations.chart : chart.chart_id], signalfx_list_chart.failure_fingerprints.id)
    )
    error_message = "ARC dashboard must preserve the telemetry-to-capacity-to-workload operator flow and all 16 chart placements."
  }
}
