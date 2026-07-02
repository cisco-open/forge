# Splunk Observability OpenCost Dashboard

This module creates the OpenCost tenant cost dashboard.

## Why This Module Exists

Forge operators need a Kubernetes-side cost view for ARC tenant namespaces. This dashboard turns OpenCost CPU and memory allocation metrics into tenant-level hourly cost and monthly run-rate views.

## What It Manages

- Tenant hourly compute allocation cost.
- Tenant monthly compute run rate.
- CPU and memory cost trends by tenant namespace.
- Top pods by compute allocation cost.
- Dashboard parent relationship in the shared O11y group.

## Operational Notes

- Tenant scope uses the OpenCost `namespace` metric label and the Forge K8S tenant namespace list.
- Cluster scope uses the OpenCost `cluster_id` metric label and the Forge K8S cluster suggestions.
- This estimates Kubernetes compute allocation cost from OpenCost metrics; it is not an AWS invoice or CUR-backed bill.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_signalfx"></a> [signalfx](#requirement\_signalfx) | < 10.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_signalfx"></a> [signalfx](#provider\_signalfx) | 9.30.3 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [signalfx_dashboard.opencost](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/dashboard) | resource |
| [signalfx_list_chart.tenant_hourly_compute_cost](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.tenant_monthly_compute_run_rate](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.top_pod_compute_cost](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_time_chart.tenant_compute_cost_trend](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.tenant_cpu_cost](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.tenant_memory_cost](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_dashboard_group"></a> [dashboard\_group](#input\_dashboard\_group) | Dashboard group name for organizing dashboards. | `string` | n/a | yes |
| <a name="input_dynamic_variables"></a> [dynamic\_variables](#input\_dynamic\_variables) | Additional dynamic variable definitions for deriving dashboard filters. | <pre>list(object({<br/>    property               = string<br/>    alias                  = string<br/>    description            = string<br/>    values                 = list(string)<br/>    value_required         = bool<br/>    values_suggested       = list(string)<br/>    restricted_suggestions = bool<br/>  }))</pre> | `[]` | no |
| <a name="input_tenant_names"></a> [tenant\_names](#input\_tenant\_names) | Tenant namespaces used to scope OpenCost allocation metrics. | `list(string)` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
