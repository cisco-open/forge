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
| [signalfx_dashboard.runner_ec2](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/dashboard) | resource |
| [signalfx_list_chart.chart_active_hosts_by_availability_zone](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.chart_active_hosts_per_instance_type](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.chart_disk_metrics_24h_change](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.chart_disk_summary_utilization](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.chart_top_5_network_in_bytes](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.chart_top_5_network_out_bytes](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.chart_top_images_by_mean_cpu_utilization](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.chart_top_instances_by_cpu_utilization](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.chart_top_memory_page_swaps_sec](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.chart_total_network_errors](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_single_value_chart.chart_active_hosts](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/single_value_chart) | resource |
| [signalfx_single_value_chart.chart_hosts_with_agent_installed](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/single_value_chart) | resource |
| [signalfx_time_chart.chart_cpu_utilization](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.chart_disk_io_bytes](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.chart_disk_ops](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.chart_disk_utilization](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.chart_memory_utilization](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.chart_network_in_bytes](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.chart_network_in_bytes_vs_24h_change](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.chart_network_out_bytes](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.chart_network_out_bytes_vs_24h_change](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.chart_total_memory_overview_bytes](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_dashboard_group"></a> [dashboard\_group](#input\_dashboard\_group) | Dashboard group name for organizing dashboards. | `string` | n/a | yes |
| <a name="input_dynamic_variables"></a> [dynamic\_variables](#input\_dynamic\_variables) | Additional dynamic variable definitions for the dashboard. | <pre>list(object({<br/>    property               = string<br/>    alias                  = string<br/>    description            = string<br/>    values                 = list(string)<br/>    value_required         = bool<br/>    values_suggested       = list(string)<br/>    restricted_suggestions = bool<br/>  }))</pre> | `[]` | no |
| <a name="input_tenant_names"></a> [tenant\_names](#input\_tenant\_names) | List of tenant names used for the dashboard. | `list(string)` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
