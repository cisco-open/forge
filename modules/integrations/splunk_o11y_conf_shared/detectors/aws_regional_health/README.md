# Forge AWS Platform Health Detectors

The regional detector applies the stable queued-build thresholds carried by
the regional platform dashboard:

- Major when oldest queued-build age remains above 300 seconds for 10 minutes.
- Warning when oldest age remains above 75 seconds and visible backlog remains
  above 10 messages for 10 minutes.
- Major when a queued-build dead-letter queue receives a message in five
  minutes.

The oldest-age Major rule and the combined backlog Warning rule clear only
after oldest queued-build age remains below 60 seconds for 15 minutes. The DLQ
rule evaluates the rolling five-minute send count and activates when that count
is non-zero.

Tenant-assigned Lambda throttle totals remain diagnostic-only at the regional
level because their baselines vary materially by tenant and region. The
control-plane detector only evaluates shared functions without a TenantName
tag and requires sustained throttling before alerting.

The runner-log delivery detector also monitors the Firehose Kinesis source
reader. It warns when the reader remains more than five minutes behind for 10
minutes, becomes critical above 15 minutes or when input continues while reads
stop, and reports sustained source-reader throttling. It clears lag alerts only
after lag remains below one minute for 10 minutes.

## Ownership and configuration

This detector is an internal submodule of `splunk_o11y_conf_shared`; deploy the
parent module rather than calling this directory directly. The parent always
creates the detector and passes:

- dynamic metric-property scope from
  `dashboard_variables.aws_regional_health.dynamic_variables`;
- the configured Splunk Observability team;
- `detector_name_prefix`; and
- the shared detector notification routing.

The detector code does not know deployment-specific tag property names. It
uses the configured and suggested values for each supplied dynamic property.
Missing required values or a missing dynamic scope produce non-matching
filters, so an incomplete configuration cannot create an organization-wide
detector accidentally.

The control-plane detector excludes tenant-tagged resources and monitors:

- sustained errors and throttles in shared Forge Lambda functions;
- sustained backlog and oldest-message age in shared SQS queues; and
- visible messages in control-plane dead-letter queues, including
  `dead-letter`, `dead_letter`, and `dlq` naming conventions.

The charts that provide incident context are managed by the
[AWS regional platform dashboard](../../dashboards/aws_regional_health/README.md).
Use the Lambda and SQS control-plane dashboards for shared-resource incidents.
Use the
[dashboard runbook](../../../../../docs/operations/splunk-o11y-dashboard-runbook.md)
for triage and recovery, and the
[panel reference](../../../../../docs/operations/splunk-o11y-dashboard-panel-reference.md)
for the chart inventory.

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
| [signalfx_detector.aws_control_plane_health](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/detector) | resource |
| [signalfx_detector.aws_regional_platform_health](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/detector) | resource |
| [signalfx_detector.aws_sqs_control_plane_health](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/detector) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_detector_name_prefix"></a> [detector\_name\_prefix](#input\_detector\_name\_prefix) | Prefix to use for Splunk Observability detector names. | `string` | n/a | yes |
| <a name="input_detector_notifications"></a> [detector\_notifications](#input\_detector\_notifications) | Detector notification destinations. | `list(string)` | n/a | yes |
| <a name="input_dynamic_variables"></a> [dynamic\_variables](#input\_dynamic\_variables) | Dynamic metric property definitions used to scope regional platform detectors. | <pre>list(object({<br/>    property               = string<br/>    alias                  = string<br/>    description            = string<br/>    values                 = list(string)<br/>    value_required         = bool<br/>    values_suggested       = list(string)<br/>    restricted_suggestions = bool<br/>  }))</pre> | n/a | yes |
| <a name="input_team"></a> [team](#input\_team) | Splunk Observability team ID. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_detector_id"></a> [detector\_id](#output\_detector\_id) | AWS regional platform detector ID for linking queue-health charts. |
| <a name="output_lambda_control_plane_detector_id"></a> [lambda\_control\_plane\_detector\_id](#output\_lambda\_control\_plane\_detector\_id) | AWS Lambda control-plane detector ID for linking Lambda health charts. |
| <a name="output_sqs_control_plane_detector_id"></a> [sqs\_control\_plane\_detector\_id](#output\_sqs\_control\_plane\_detector\_id) | AWS SQS control-plane detector ID for linking SQS health charts. |
<!-- END_TF_DOCS -->
