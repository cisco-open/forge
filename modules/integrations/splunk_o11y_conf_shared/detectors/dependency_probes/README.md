# Tenant dependency-probe detectors

Creates one Splunk Observability detector per Forge tenant. Each detector has
rules for:

- missing probe telemetry;
- unavailable regional SSM GitHub App parameters;
- failed GitHub App authentication or organization runner API access; and
- low GitHub REST API rate-limit budget.

The detector keeps `AWSRegion` in the output MTS so a tenant
incident identifies the affected Forge deployment region.

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
| <a name="input_detector_config"></a> [detector\_config](#input\_detector\_config) | Thresholds and durations for tenant dependency detectors. | <pre>object({<br/>    failure_duration                   = string<br/>    no_data_duration                   = string<br/>    no_data_fill_duration              = string<br/>    rate_limit_duration                = string<br/>    rate_limit_remaining_pct_threshold = number<br/>  })</pre> | n/a | yes |
| <a name="input_detector_name_prefix"></a> [detector\_name\_prefix](#input\_detector\_name\_prefix) | Prefix to use for Splunk Observability detector names. | `string` | n/a | yes |
| <a name="input_detector_notifications"></a> [detector\_notifications](#input\_detector\_notifications) | Detector notification destinations. | `list(string)` | n/a | yes |
| <a name="input_team"></a> [team](#input\_team) | Splunk Observability team ID. | `string` | n/a | yes |
| <a name="input_tenant_names"></a> [tenant\_names](#input\_tenant\_names) | Forge tenants that require independent dependency detectors. | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_detector_ids"></a> [detector\_ids](#output\_detector\_ids) | Dependency detector IDs keyed by tenant for linking dashboard charts. |
<!-- END_TF_DOCS -->
