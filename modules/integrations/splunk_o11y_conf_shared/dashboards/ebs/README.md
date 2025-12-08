<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_signalfx"></a> [signalfx](#requirement\_signalfx) | < 10.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_signalfx"></a> [signalfx](#provider\_signalfx) | 9.23.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [signalfx_dashboard.ebs](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/dashboard) | resource |
| [signalfx_single_value_chart.state](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/single_value_chart) | resource |
| [signalfx_time_chart.avg_queue_length](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.byte_utilization_pct](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.idle_time](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.latency_op](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.read_latency](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.read_ops](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.read_throughput](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.read_vs_write_ops](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.rw_bytes_breakdown](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.total_read_time](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.total_write_time](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.write_latency](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.write_ops](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.write_throughput](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_dashboard_group"></a> [dashboard\_group](#input\_dashboard\_group) | Dashboard group name for organizing dashboards. | `string` | n/a | yes |
| <a name="input_dynamic_variables"></a> [dynamic\_variables](#input\_dynamic\_variables) | Additional dynamic variable definitions for the dashboard. | <pre>list(object({<br/>    property               = string<br/>    alias                  = string<br/>    description            = string<br/>    values                 = list(string)<br/>    value_required         = bool<br/>    values_suggested       = list(string)<br/>    restricted_suggestions = bool<br/>  }))</pre> | `[]` | no |
| <a name="input_tenant_names"></a> [tenant\_names](#input\_tenant\_names) | List of tenant names used for the dashboard. | `list(string)` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
