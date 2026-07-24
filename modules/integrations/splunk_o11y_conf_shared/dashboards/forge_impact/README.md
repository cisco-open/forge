# Splunk Observability Forge Impact Dashboard

This module creates separate Forge tenant-impact and runner-usage dashboards.

## Why This Module Exists

Operators need one place to identify which tenants are most affected before
opening a subsystem dashboard. The dashboard starts with top-10 tenant
leaderboards for live-backed Lambda, EC2, Kubernetes, SQS, and EBS signals.
Runner adoption and workload-shape charts live in a separate usage dashboard
so they do not dilute the incident landing page.

## What It Manages

- Top tenants by Lambda errors and throttles.
- Top tenants by EC2 runner CPU, memory, disk, and status-check failures.
- Top tenant namespaces by pending, failed, unknown, or restarting Kubernetes workloads.
- Top tenants by SQS and dead-letter backlog.
- Top tenants by EBS queue length and exceeded IOPS limits.
- Runner totals and minutes by runtime.
- Active EC2 runners by tenant and instance type.
- EC2 runner hours and total runners by tenant.
- Kubernetes runner totals and hours by tenant.
- Dashboard parent relationship in the shared O11y group.

## Operational Notes

- Start here during incidents to identify affected tenants and the subsystem
  that needs deeper investigation.
- Tenant properties remain visible in each leaderboard so the same identity can
  be used in the matching subsystem dashboard.
- Open `Forge Runner Usage` for capacity planning and stakeholder reporting.
- Tenant names must be consistently emitted as dimensions.
- Kubernetes signals are restricted to configured Forge clusters and tenant namespaces.
- Required AWS scope values are embedded in SignalFlow so they cannot suppress
  Kubernetes charts that do not carry AWS tag dimensions.
- DynamoDB throttling and system-error leaderboards are intentionally absent:
  the live metrics do not currently expose a confirmed tenant identity.
- Use subsystem dashboards for resource-level diagnosis after identifying the
  tenant and issue category here.

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
| [signalfx_dashboard.forge_impact](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/dashboard) | resource |
| [signalfx_dashboard.runner_usage](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/dashboard) | resource |
| [signalfx_list_chart.active_ec2_runners_by_tenant](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.active_ec2_runners_by_tenant_and_instance_type](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.ec2_runner_hours_by_tenant](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.ec2_runner_hours_by_tenant_and_instance_type](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.k8s_runner_hours_by_tenant](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.k8s_runners_by_tenant](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.runner_minutes_by_runtime](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.runner_totals_by_runtime](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.top_tenants_ebs_iops_exceeded](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.top_tenants_ebs_queue_length](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.top_tenants_ec2_cpu](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.top_tenants_ec2_disk](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.top_tenants_ec2_memory](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.top_tenants_ec2_status_failures](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.top_tenants_k8s_failed_pods](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.top_tenants_k8s_pending_pods](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.top_tenants_k8s_restarts](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.top_tenants_lambda_errors](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.top_tenants_lambda_throttles](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.top_tenants_sqs_backlog](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.top_tenants_sqs_dlq_backlog](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.total_ec2_runners_by_tenant](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.total_k8s_runners_by_tenant](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_time_chart.active_ec2_runners_by_tenant_and_instance_type](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [terraform_data.dashboard_parent](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.runner_usage_dashboard_parent](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_names"></a> [cluster\_names](#input\_cluster\_names) | Forge Kubernetes clusters included in global tenant impact and runner usage. | `list(string)` | `[]` | no |
| <a name="input_dashboard_group"></a> [dashboard\_group](#input\_dashboard\_group) | Dashboard group name for organizing dashboards. | `string` | n/a | yes |
| <a name="input_dynamic_variables"></a> [dynamic\_variables](#input\_dynamic\_variables) | Additional dynamic variable definitions for the dashboard. | <pre>list(object({<br/>    property               = string<br/>    alias                  = string<br/>    description            = string<br/>    values                 = list(string)<br/>    value_required         = bool<br/>    values_suggested       = list(string)<br/>    restricted_suggestions = bool<br/>  }))</pre> | `[]` | no |
| <a name="input_tenant_names"></a> [tenant\_names](#input\_tenant\_names) | Tenant namespaces that run Forge ARC runners. | `list(string)` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
