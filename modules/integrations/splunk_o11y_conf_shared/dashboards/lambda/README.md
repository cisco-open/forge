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
| [signalfx_dashboard.lambda](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/dashboard) | resource |
| [signalfx_list_chart.avg_duration_by_version](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.percent_invocations_by_version](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_single_value_chart.avg_invocation_duration](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/single_value_chart) | resource |
| [signalfx_single_value_chart.total_errors](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/single_value_chart) | resource |
| [signalfx_single_value_chart.total_invocations](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/single_value_chart) | resource |
| [signalfx_single_value_chart.total_spillover_invocations](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/single_value_chart) | resource |
| [signalfx_single_value_chart.total_throttles](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/single_value_chart) | resource |
| [signalfx_time_chart.errors_by_version](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.invocations](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.invocations_by_version](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.provisioned_concurrency_invocations_by_version](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.provisioned_concurrency_spillover_invocations_by_version](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.provisioned_concurrency_utilization](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.provisioned_concurrent_executions_by_version](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.throttles_by_version](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_dashboard_group"></a> [dashboard\_group](#input\_dashboard\_group) | Dashboard group name for organizing dashboards. | `string` | n/a | yes |
| <a name="input_dynamic_variables"></a> [dynamic\_variables](#input\_dynamic\_variables) | Additional dynamic variable definitions for the dashboard. | <pre>list(object({<br/>    property               = string<br/>    alias                  = string<br/>    description            = string<br/>    values                 = list(string)<br/>    value_required         = bool<br/>    values_suggested       = list(string)<br/>    restricted_suggestions = bool<br/>  }))</pre> | `[]` | no |
| <a name="input_tenant_names"></a> [tenant\_names](#input\_tenant\_names) | List of tenant names used for the dashboard. | `list(string)` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
