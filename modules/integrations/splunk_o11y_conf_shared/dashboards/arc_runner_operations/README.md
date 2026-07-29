# Splunk Observability ARC Runner Operations Dashboard

This module creates the `Forge ARC Runner Operations` dashboard from the
Prometheus metrics emitted by the ARC controller and scale-set listeners.

## Operator Workflow

1. Confirm active scale sets, listeners, and controller runner state.
1. Compare desired, registered, busy, idle, and maximum runner capacity.
1. Check whether started and completed job rates diverge.
1. Separate startup delay from execution duration.
1. Use repository, workflow, job, event, result, ref, and target fingerprints
   to open the matching GitHub run and Splunk logs.

The charts intentionally avoid severity thresholds. Capacity, utilization, and
latency are evidence that must be correlated with sustained user impact,
Kubernetes state, and logs before changing a runner lane or assigning
ownership.

## Telemetry Contract

- Listener gauges: `gha_assigned_jobs`, `gha_running_jobs`,
  `gha_registered_runners`, `gha_busy_runners`, `gha_min_runners`,
  `gha_max_runners`, `gha_desired_runners`, and `gha_idle_runners`.
- Listener counters: `gha_started_jobs_total` and
  `gha_completed_jobs_total`.
- Listener histograms: `gha_job_startup_duration_seconds` and
  `gha_job_execution_duration_seconds`.
- Controller gauges: pending, running, and failed ephemeral runners and
  running listeners.

Listener counters reset when the listener restarts, so throughput charts use
rates rather than raw totals. Native histogram charts require the Splunk OTel
Prometheus receiver and SignalFx histogram exporter.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_signalfx"></a> [signalfx](#requirement\_signalfx) | < 10.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_signalfx"></a> [signalfx](#provider\_signalfx) | 9.33.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [signalfx_dashboard.arc_runner_operations](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/dashboard) | resource |
| [signalfx_list_chart.capacity_gap](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.failure_fingerprints](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.runner_utilization](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.slow_workflows](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.top_workflows](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_single_value_chart.active_scale_sets](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/single_value_chart) | resource |
| [signalfx_single_value_chart.failed_ephemeral_runners](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/single_value_chart) | resource |
| [signalfx_single_value_chart.registered_runners](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/single_value_chart) | resource |
| [signalfx_single_value_chart.running_listeners](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/single_value_chart) | resource |
| [signalfx_time_chart.completion_outcomes](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.controller_state](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.execution_latency](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.job_throughput](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.runner_supply](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.startup_latency](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.success_rate](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [terraform_data.dashboard_parent](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_dashboard_group"></a> [dashboard\_group](#input\_dashboard\_group) | Splunk Observability dashboard group ID. | `string` | n/a | yes |
| <a name="input_dynamic_variables"></a> [dynamic\_variables](#input\_dynamic\_variables) | Cluster and environment variables applied to the ARC dashboard. | <pre>list(object({<br/>    property               = string<br/>    alias                  = string<br/>    description            = string<br/>    values                 = list(string)<br/>    value_required         = bool<br/>    values_suggested       = list(string)<br/>    restricted_suggestions = bool<br/>  }))</pre> | `[]` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
