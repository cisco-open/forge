locals {
  arc_cluster_names = sort(distinct(flatten([
    for variable in var.dynamic_variables : variable.values_suggested
    if variable.property == "k8s.cluster.name"
  ])))
  arc_configured_cluster_filter = length(local.arc_cluster_names) > 0 ? join(" or ", [
    for cluster_name in local.arc_cluster_names : "filter('k8s.cluster.name', '${cluster_name}')"
  ]) : "filter('k8s.cluster.name', '__forge_cluster_scope_not_configured__')"
  arc_tenant_namespace_filter = length(var.tenant_names) > 0 ? join(" or ", [
    for tenant_name in sort(var.tenant_names) : "filter('k8s.namespace.name', '${tenant_name}')"
  ]) : "filter('k8s.namespace.name', '__forge_tenant_scope_not_configured__')"
  arc_cluster_filter       = "(${local.arc_configured_cluster_filter}) and (${local.arc_tenant_namespace_filter})"
  arc_scale_set_dimensions = "['k8s.cluster.name', 'namespace', 'name']"
}

resource "signalfx_single_value_chart" "active_scale_sets" {
  name        = "Active ARC scale sets"
  description = "Scale sets currently reporting desired-runner telemetry. If this and the adjacent ARC charts are empty, verify the listener scrape and Splunk OTel pipeline before diagnosing runner capacity."

  program_text = "A = data('gha_desired_runners', filter=(${local.arc_cluster_filter}), rollup='latest').sum(by=${local.arc_scale_set_dimensions}).count().publish(label='A')"

  color_by                = "Dimension"
  max_precision           = 0
  refresh_interval        = 30
  secondary_visualization = "Sparkline"

  viz_options {
    display_name = "Scale sets"
    label        = "A"
  }
}

resource "signalfx_single_value_chart" "registered_runners" {
  name        = "Registered runners"
  description = "Current registered runner capacity across the configured Forge clusters. Compare with desired, busy, and idle runners before changing scale-set limits."

  program_text = "A = data('gha_registered_runners', filter=(${local.arc_cluster_filter}), rollup='latest').sum(by=${local.arc_scale_set_dimensions}).sum().publish(label='A')"

  color_by                = "Dimension"
  max_precision           = 0
  refresh_interval        = 30
  secondary_visualization = "Sparkline"

  viz_options {
    display_name = "Registered"
    label        = "A"
  }
}

resource "signalfx_single_value_chart" "running_listeners" {
  name        = "Running ARC listeners"
  description = "Controller-manager view of running listeners. A drop is a control-plane symptom; correlate it with listener pod phase, restarts, and controller logs."

  program_text = "A = data('gha_controller_running_listeners', filter=(${local.arc_cluster_filter}), rollup='latest').sum().publish(label='A')"

  color_by                = "Dimension"
  max_precision           = 0
  refresh_interval        = 30
  secondary_visualization = "Sparkline"

  viz_options {
    display_name = "Listeners"
    label        = "A"
  }
}

resource "signalfx_single_value_chart" "failed_ephemeral_runners" {
  name        = "Failed ephemeral runners"
  description = "Current controller-reported failed ephemeral runners. A nonzero value identifies impact but not ownership; inspect pod status, scheduling, image pulls, storage, and controller events."

  program_text = "A = data('gha_controller_failed_ephemeral_runners', filter=(${local.arc_cluster_filter}), rollup='latest').sum().publish(label='A')"

  color_by                = "Dimension"
  max_precision           = 0
  refresh_interval        = 30
  secondary_visualization = "Sparkline"

  viz_options {
    display_name = "Failed"
    label        = "A"
  }
}

resource "signalfx_time_chart" "controller_state" {
  name        = "ARC controller runner state"
  description = "Pending, running, and failed ephemeral runners reported by the controller. Use this to decide whether job pressure reached Kubernetes or remained at the listener/dispatch layer."

  program_text = <<-EOF
P = data('gha_controller_pending_ephemeral_runners', filter=(${local.arc_cluster_filter}), rollup='latest').sum(by=['k8s.cluster.name']).publish(label='Pending')
R = data('gha_controller_running_ephemeral_runners', filter=(${local.arc_cluster_filter}), rollup='latest').sum(by=['k8s.cluster.name']).publish(label='Running')
F = data('gha_controller_failed_ephemeral_runners', filter=(${local.arc_cluster_filter}), rollup='latest').sum(by=['k8s.cluster.name']).publish(label='Failed')
EOF

  plot_type                 = "LineChart"
  axes_include_zero         = true
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "plot_label"

  axis_left {
    label = "Ephemeral runners"
  }

  legend_options_fields {
    enabled  = true
    property = "k8s.cluster.name"
  }
}

resource "signalfx_time_chart" "runner_supply" {
  name        = "Runner and job pressure by scale set"
  description = "Assigned and running-or-queued jobs alongside desired, registered, busy, idle, and maximum runners. Sustained busy capacity alone is not an incident; correlate it with job pressure and startup latency."

  program_text = <<-EOF
A = data('gha_assigned_jobs', filter=(${local.arc_cluster_filter}), rollup='latest').sum(by=${local.arc_scale_set_dimensions}).publish(label='Assigned jobs')
J = data('gha_running_jobs', filter=(${local.arc_cluster_filter}), rollup='latest').sum(by=${local.arc_scale_set_dimensions}).publish(label='Running or queued jobs')
D = data('gha_desired_runners', filter=(${local.arc_cluster_filter}), rollup='latest').sum(by=${local.arc_scale_set_dimensions}).publish(label='Desired')
R = data('gha_registered_runners', filter=(${local.arc_cluster_filter}), rollup='latest').sum(by=${local.arc_scale_set_dimensions}).publish(label='Registered')
B = data('gha_busy_runners', filter=(${local.arc_cluster_filter}), rollup='latest').sum(by=${local.arc_scale_set_dimensions}).publish(label='Busy')
I = data('gha_idle_runners', filter=(${local.arc_cluster_filter}), rollup='latest').sum(by=${local.arc_scale_set_dimensions}).publish(label='Idle')
M = data('gha_max_runners', filter=(${local.arc_cluster_filter}), rollup='latest').sum(by=${local.arc_scale_set_dimensions}).publish(label='Maximum')
EOF

  plot_type                 = "LineChart"
  axes_include_zero         = true
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "plot_label"

  axis_left {
    label = "Jobs and runners"
  }

  legend_options_fields {
    enabled  = true
    property = "namespace"
  }
  legend_options_fields {
    enabled  = true
    property = "name"
  }
}

resource "signalfx_list_chart" "capacity_gap" {
  name        = "Scale sets below desired registered capacity"
  description = "Positive desired-minus-registered gaps by scale set. Confirm that the gap persists and correlates with startup latency, pending pods, or registration failures before changing capacity."

  program_text = <<-EOF
D = data('gha_desired_runners', filter=(${local.arc_cluster_filter}), rollup='latest').sum(by=${local.arc_scale_set_dimensions})
R = data('gha_registered_runners', filter=(${local.arc_cluster_filter}), rollup='latest').sum(by=${local.arc_scale_set_dimensions})
G = (D - R).above(0).top(count=20).publish(label='Gap')
EOF

  sort_by                 = "-value"
  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"

  legend_options_fields {
    enabled  = true
    property = "k8s.cluster.name"
  }
  legend_options_fields {
    enabled  = true
    property = "namespace"
  }
  legend_options_fields {
    enabled  = true
    property = "name"
  }

  viz_options {
    display_name = "Desired - registered"
    label        = "Gap"
  }
}

resource "signalfx_list_chart" "runner_utilization" {
  name        = "Runner utilization by scale set"
  description = "Busy runners divided by registered runners. Sustained high utilization is supporting evidence only; use job throughput and startup latency to confirm user impact."

  program_text = <<-EOF
B = data('gha_busy_runners', filter=(${local.arc_cluster_filter}), rollup='latest').sum(by=${local.arc_scale_set_dimensions})
R = data('gha_registered_runners', filter=(${local.arc_cluster_filter}), rollup='latest').sum(by=${local.arc_scale_set_dimensions}).above(0, inclusive=False)
U = (B / R * 100).top(count=20).publish(label='Utilization')
EOF

  sort_by                 = "-value"
  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"

  legend_options_fields {
    enabled  = true
    property = "k8s.cluster.name"
  }
  legend_options_fields {
    enabled  = true
    property = "namespace"
  }
  legend_options_fields {
    enabled  = true
    property = "name"
  }

  viz_options {
    display_name = "Busy / registered"
    label        = "Utilization"
    value_suffix = "%"
  }
}

resource "signalfx_time_chart" "job_throughput" {
  name        = "Job arrival and completion throughput"
  description = "Started and completed jobs per minute. ARC listener counters reset on listener restart, so this chart uses counter rates rather than raw totals. A sustained divergence suggests work buildup but does not identify the cause."

  program_text = <<-EOF
S = data('gha_started_jobs_total', filter=(${local.arc_cluster_filter}), rollup='rate', extrapolation='zero').sum().scale(60).publish(label='Started')
C = data('gha_completed_jobs_total', filter=(${local.arc_cluster_filter}), rollup='rate', extrapolation='zero').sum().scale(60).publish(label='Completed')
EOF

  plot_type                 = "LineChart"
  axes_include_zero         = true
  axes_precision            = 2
  disable_sampling          = true
  on_chart_legend_dimension = "plot_label"

  axis_left {
    label = "Jobs per minute"
  }
}

resource "signalfx_time_chart" "completion_outcomes" {
  name        = "Completion outcomes"
  description = "Completed jobs per minute grouped by GitHub result. Failures can be tenant-workload failures; correlate repository, workflow, job, and logs before assigning Forge ownership."

  program_text = "A = data('gha_completed_jobs_total', filter=(${local.arc_cluster_filter}), rollup='rate', extrapolation='zero').sum(by=['job_result']).scale(60).publish(label='A')"

  plot_type                 = "ColumnChart"
  axes_include_zero         = true
  axes_precision            = 2
  disable_sampling          = true
  on_chart_legend_dimension = "job_result"

  axis_left {
    label = "Jobs per minute"
  }

  legend_options_fields {
    enabled  = true
    property = "job_result"
  }

  viz_options {
    display_name = "Completed jobs"
    label        = "A"
  }
}

resource "signalfx_time_chart" "success_rate" {
  name        = "Job success rate"
  description = "Successful completions divided by all completions. Interpret changes with job volume and failure fingerprints; low-volume windows can move sharply."

  program_text = <<-EOF
S = data('gha_completed_jobs_total', filter=(${local.arc_cluster_filter}) and filter('job_result', 'success'), rollup='rate', extrapolation='zero').sum()
T = data('gha_completed_jobs_total', filter=(${local.arc_cluster_filter}), rollup='rate', extrapolation='zero').sum().above(0, inclusive=False)
R = (S / T * 100).publish(label='Success rate')
EOF

  plot_type         = "LineChart"
  axes_include_zero = true
  axes_precision    = 2
  disable_sampling  = true

  axis_left {
    label     = "Percent"
    max_value = 100
    min_value = 0
  }

  viz_options {
    display_name = "Success rate"
    label        = "Success rate"
    value_suffix = "%"
  }
}

resource "signalfx_time_chart" "startup_latency" {
  name        = "Job startup latency"
  description = "P50, P90, and P99 seconds from assignment until the job starts on an ARC runner. Rising startup latency with a capacity gap points toward scaling, scheduling, registration, image, or storage investigation."

  program_text = <<-EOF
P50 = histogram('gha_job_startup_duration_seconds', filter=(${local.arc_cluster_filter})).percentile(pct=50, over='15m').publish(label='P50')
P90 = histogram('gha_job_startup_duration_seconds', filter=(${local.arc_cluster_filter})).percentile(pct=90, over='15m').publish(label='P90')
P99 = histogram('gha_job_startup_duration_seconds', filter=(${local.arc_cluster_filter})).percentile(pct=99, over='15m').publish(label='P99')
EOF

  plot_type                 = "LineChart"
  axes_include_zero         = true
  axes_precision            = 2
  disable_sampling          = true
  on_chart_legend_dimension = "plot_label"

  axis_left {
    label = "Seconds"
  }
}

resource "signalfx_time_chart" "execution_latency" {
  name        = "Job execution duration"
  description = "P50, P90, and P99 execution seconds. Rising execution duration with stable startup latency usually points toward workload behavior or runner resource sizing rather than ARC dispatch."

  program_text = <<-EOF
P50 = histogram('gha_job_execution_duration_seconds', filter=(${local.arc_cluster_filter})).percentile(pct=50, over='15m').publish(label='P50')
P90 = histogram('gha_job_execution_duration_seconds', filter=(${local.arc_cluster_filter})).percentile(pct=90, over='15m').publish(label='P90')
P99 = histogram('gha_job_execution_duration_seconds', filter=(${local.arc_cluster_filter})).percentile(pct=99, over='15m').publish(label='P99')
EOF

  plot_type                 = "LineChart"
  axes_include_zero         = true
  axes_precision            = 2
  disable_sampling          = true
  on_chart_legend_dimension = "plot_label"

  axis_left {
    label = "Seconds"
  }
}

resource "signalfx_list_chart" "top_workflows" {
  name        = "Top workflow and job demand"
  description = "Highest completed-job rates by repository, workflow, and job. Use this to identify the workload producing demand before changing a shared runner lane."

  program_text = "A = data('gha_completed_jobs_total', filter=(${local.arc_cluster_filter}), rollup='rate', extrapolation='zero').sum(by=['organization', 'repository', 'job_workflow_name', 'job_name', 'event_name']).scale(60).top(count=20).publish(label='A')"

  sort_by                 = "-value"
  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"

  legend_options_fields {
    enabled  = true
    property = "organization"
  }
  legend_options_fields {
    enabled  = true
    property = "repository"
  }
  legend_options_fields {
    enabled  = true
    property = "job_workflow_name"
  }
  legend_options_fields {
    enabled  = true
    property = "job_name"
  }
  legend_options_fields {
    enabled  = true
    property = "event_name"
  }

  viz_options {
    display_name = "Completed jobs per minute"
    label        = "A"
  }
}

resource "signalfx_list_chart" "slow_workflows" {
  name        = "Slow startup fingerprints"
  description = "Top P90 startup latency over 15 minutes by repository, workflow, and job. Correlate repeated fingerprints with scale-set capacity and Kubernetes evidence; one slow job is not a sizing decision."

  program_text = "A = histogram('gha_job_startup_duration_seconds', filter=(${local.arc_cluster_filter})).percentile(pct=90, by=['organization', 'repository', 'job_workflow_name', 'job_name', 'event_name'], over='15m').top(count=20).publish(label='A')"

  sort_by                 = "-value"
  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"

  legend_options_fields {
    enabled  = true
    property = "organization"
  }
  legend_options_fields {
    enabled  = true
    property = "repository"
  }
  legend_options_fields {
    enabled  = true
    property = "job_workflow_name"
  }
  legend_options_fields {
    enabled  = true
    property = "job_name"
  }
  legend_options_fields {
    enabled  = true
    property = "event_name"
  }

  viz_options {
    display_name = "P90 startup seconds"
    label        = "A"
  }
}

resource "signalfx_list_chart" "failure_fingerprints" {
  name        = "Non-successful job fingerprints"
  description = "Highest non-success completion rates with repository, workflow, job, event, result, ref, and target. Open the matching GitHub run and Splunk logs before classifying Forge, tenant, or dependency ownership."

  program_text = "A = data('gha_completed_jobs_total', filter=(${local.arc_cluster_filter}) and (not filter('job_result', 'success')), rollup='rate', extrapolation='zero').sum(by=['organization', 'repository', 'job_workflow_name', 'job_name', 'event_name', 'job_result', 'job_workflow_ref', 'job_workflow_target']).scale(60).top(count=20).publish(label='A')"

  sort_by                 = "-value"
  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"

  legend_options_fields {
    enabled  = true
    property = "organization"
  }
  legend_options_fields {
    enabled  = true
    property = "repository"
  }
  legend_options_fields {
    enabled  = true
    property = "job_workflow_name"
  }
  legend_options_fields {
    enabled  = true
    property = "job_name"
  }
  legend_options_fields {
    enabled  = true
    property = "event_name"
  }
  legend_options_fields {
    enabled  = true
    property = "job_result"
  }
  legend_options_fields {
    enabled  = true
    property = "job_workflow_ref"
  }
  legend_options_fields {
    enabled  = true
    property = "job_workflow_target"
  }

  viz_options {
    display_name = "Non-success jobs per minute"
    label        = "A"
  }
}

resource "terraform_data" "dashboard_parent" {
  triggers_replace = var.dashboard_group
}

resource "signalfx_dashboard" "arc_runner_operations" {
  name            = "Forge ARC Runner Operations"
  description     = "Operator path: verify ARC telemetry and controller state, compare demand with registered capacity, inspect job throughput and outcomes, then use high-cardinality workflow fingerprints to route the investigation. Metrics identify symptoms; correlate Kubernetes and Splunk logs before assigning ownership."
  dashboard_group = var.dashboard_group
  time_range      = "-1h"

  lifecycle {
    replace_triggered_by = [
      terraform_data.dashboard_parent,
    ]
  }

  variable {
    property               = "k8s.namespace.name"
    alias                  = "ForgeCICD Tenant Name"
    description            = "Limit ARC controller and listener metrics to a configured tenant namespace."
    values                 = []
    value_required         = false
    values_suggested       = sort(var.tenant_names)
    restricted_suggestions = true
  }

  dynamic "variable" {
    for_each = var.dynamic_variables
    iterator = var_def

    content {
      property               = var_def.value.property
      alias                  = var_def.value.alias
      description            = var_def.value.description
      values                 = var_def.value.values
      value_required         = var_def.value.value_required
      values_suggested       = var_def.value.values_suggested
      restricted_suggestions = var_def.value.restricted_suggestions
    }
  }

  chart {
    chart_id = signalfx_single_value_chart.active_scale_sets.id
    row      = 0
    column   = 0
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_single_value_chart.registered_runners.id
    row      = 0
    column   = 3
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_single_value_chart.running_listeners.id
    row      = 0
    column   = 6
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_single_value_chart.failed_ephemeral_runners.id
    row      = 0
    column   = 9
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.controller_state.id
    row      = 1
    column   = 0
    width    = 5
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.runner_supply.id
    row      = 1
    column   = 5
    width    = 7
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.capacity_gap.id
    row      = 2
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.runner_utilization.id
    row      = 2
    column   = 6
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.job_throughput.id
    row      = 3
    column   = 0
    width    = 5
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.completion_outcomes.id
    row      = 3
    column   = 5
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.success_rate.id
    row      = 3
    column   = 9
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.startup_latency.id
    row      = 4
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.execution_latency.id
    row      = 4
    column   = 6
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_workflows.id
    row      = 5
    column   = 0
    width    = 6
    height   = 2
  }

  chart {
    chart_id = signalfx_list_chart.slow_workflows.id
    row      = 5
    column   = 6
    width    = 6
    height   = 2
  }

  chart {
    chart_id = signalfx_list_chart.failure_fingerprints.id
    row      = 7
    column   = 0
    width    = 12
    height   = 2
  }
}
