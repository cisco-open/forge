<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.90 |
| <a name="requirement_signalfx"></a> [signalfx](#requirement\_signalfx) | < 10.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.23.0 |
| <a name="provider_signalfx"></a> [signalfx](#provider\_signalfx) | 9.22.3 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [signalfx_dashboard.billing](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/dashboard) | resource |
| [signalfx_dashboard.runner_ec2](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/dashboard) | resource |
| [signalfx_dashboard.runner_k8s](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/dashboard) | resource |
| [signalfx_dashboard_group.forgecicd](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/dashboard_group) | resource |
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
| [signalfx_list_chart.k8s_network_errors_per_sec](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.k8s_pods_by_phase](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.k8s_top_10_cpu_usage_per_pod](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.k8s_top_10_pods_by_avg_memory_usage](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_single_value_chart.chart_active_hosts](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/single_value_chart) | resource |
| [signalfx_single_value_chart.chart_hosts_with_agent_installed](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/single_value_chart) | resource |
| [signalfx_single_value_chart.k8s_active_pods](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/single_value_chart) | resource |
| [signalfx_single_value_chart.k8s_available_pods_by_deployments](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/single_value_chart) | resource |
| [signalfx_single_value_chart.k8s_desired_pods_by_deployments](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/single_value_chart) | resource |
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
| [signalfx_time_chart.cost_per_service](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.cost_per_tenant](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.k8s_memory_usage_bytes](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.k8s_memory_usage_pct](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.k8s_network_bytes_per_sec](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.net_cost_per_service](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.net_cost_per_tenant](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.total_cost](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.total_net_cost](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [aws_secretsmanager_secret.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret_version.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile (i.e., generated via 'sl aws session generate') to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Default AWS region. | `string` | n/a | yes |
| <a name="input_dashboard_variables"></a> [dashboard\_variables](#input\_dashboard\_variables) | Variables for Dashboards | <pre>object({<br/>    runner_k8s = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    runner_ec2 = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    billing = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>  })</pre> | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_splunk_api_url"></a> [splunk\_api\_url](#input\_splunk\_api\_url) | URL for plunk Observability Cloud API. | `string` | n/a | yes |
| <a name="input_splunk_organization_id"></a> [splunk\_organization\_id](#input\_splunk\_organization\_id) | organization ID for Splunk Observability Cloud. | `string` | n/a | yes |
| <a name="input_team"></a> [team](#input\_team) | Team ID | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
