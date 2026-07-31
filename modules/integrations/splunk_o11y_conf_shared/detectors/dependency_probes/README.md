# Tenant health detectors

Creates one Splunk Observability detector per Forge tenant. Each detector keeps
the four dependency rules and adds actionable workload-health rules for:

- missing probe telemetry;
- unavailable regional SSM GitHub App parameters;
- failed GitHub App authentication or organization runner API access; and
- low GitHub REST API rate-limit budget;
- Lambda error rate and sustained throttling;
- delayed or stuck build queues and DLQ backlog;
- pending or failed Kubernetes pods and repeated container restarts;
- EC2 status-check failures and sustained memory or disk pressure; and
- EBS provisioned-IOPS exceeded checks.

AWS alerts retain region and resource dimensions, while Kubernetes alerts retain
cluster context. Separate EC2 memory/disk detectors remain available for chart
compatibility but their notifications are suppressed when tenant-health coverage
is complete.

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

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [signalfx_detector.tenant_dependency_health](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/detector) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_detector_config"></a> [detector\_config](#input\_detector\_config) | Thresholds and durations for the dependency rules in tenant health detectors. | <pre>object({<br/>    failure_duration                   = string<br/>    no_data_duration                   = string<br/>    no_data_fill_duration              = string<br/>    rate_limit_duration                = string<br/>    rate_limit_remaining_pct_threshold = number<br/>  })</pre> | n/a | yes |
| <a name="input_detector_name_prefix"></a> [detector\_name\_prefix](#input\_detector\_name\_prefix) | Prefix to use for Splunk Observability detector names. | `string` | n/a | yes |
| <a name="input_detector_notifications"></a> [detector\_notifications](#input\_detector\_notifications) | Detector notification destinations. | `list(string)` | n/a | yes |
| <a name="input_lambda_dimension_filter"></a> [lambda\_dimension\_filter](#input\_lambda\_dimension\_filter) | Canonical AWS Lambda resource-level SignalFlow filter. | `string` | n/a | yes |
| <a name="input_team"></a> [team](#input\_team) | Splunk Observability team ID. | `string` | n/a | yes |
| <a name="input_tenant_names"></a> [tenant\_names](#input\_tenant\_names) | Forge tenants that require independent health detectors. | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_detector_ids"></a> [detector\_ids](#output\_detector\_ids) | Tenant health detector IDs keyed by tenant for linking dashboard charts. |
<!-- END_TF_DOCS -->
