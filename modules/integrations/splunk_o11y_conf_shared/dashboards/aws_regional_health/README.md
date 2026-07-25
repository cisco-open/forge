# Forge AWS Regional Platform Health Dashboard

This dashboard codifies the regional Forge AWS control-plane panels previously
maintained manually in Splunk Observability Cloud. It intentionally remains
separate from `Forge External Dependency Health`, which covers GitHub and SSM
dependency probes.

The five panels cover:

- Lambda throttle-attempt percentage and five-minute throttle count.
- Queued-build oldest-message age and visible backlog.
- Queued-build dead-letter queue sends.

| Panel | Operational use | Alerting |
| --- | --- | --- |
| Forge AWS Lambda throttle attempt rate | Compare regional throttling with the established regional baseline. | Diagnostic only |
| Forge AWS Lambda throttle count | Confirm the absolute volume behind a throttle-rate change. | Never alert on count alone |
| Forge AWS build queue oldest age | Detect queued-build work that is no longer draining promptly. | Warning and Major detector input |
| Forge AWS build queue visible backlog | Confirm saturation together with elevated oldest-message age. | Warning detector input |
| Forge AWS queued-build DLQ sends | Identify messages entering a queued-build dead-letter queue. | Major |

The dashboard is fail-closed. Its SignalFlow scope is derived from
`aws_account_id`, `aws_region`, and `aws_tag_ProductFamilyName` values under
`dynamic_variables`. Missing scope values use non-matching sentinel filters
instead of querying every AWS account or product family.

## Configuration

Configure this dashboard only through
`dashboard_variables.aws_regional_health`. It does not inherit tenants or
dynamic variables from another dashboard.

```yaml
dashboard_variables:
  aws_regional_health:
    dynamic_variables:
      - property: aws_account_id
        alias: AWS account
        description: Forge AWS accounts included in regional platform health.
        values: []
        value_required: false
        values_suggested: ["111111111111"]
        restricted_suggestions: true
      - property: aws_region
        alias: AWS region
        description: Forge AWS regions included in regional platform health.
        values: []
        value_required: false
        values_suggested: [eu-west-1, us-east-1, us-west-2]
        restricted_suggestions: true
      - property: aws_tag_ProductFamilyName
        alias: Product family
        description: Forge product-family tag included in regional platform health.
        values: []
        value_required: false
        values_suggested: ["Forge MT"]
        restricted_suggestions: true
```

See the
[complete integration template](../../../../../examples/templates/integrations/splunk_o11y_conf_shared/config.yml).

The corresponding alert rules are managed by the
[AWS regional platform detector](../../detectors/aws_regional_health/README.md).
For day-2 interpretation, use the
[dashboard runbook](../../../../../docs/operations/splunk-o11y-dashboard-runbook.md)
and
[panel reference](../../../../../docs/operations/splunk-o11y-dashboard-panel-reference.md).

## Migration from the manual dashboard

The manual dashboard `HN_5cVmAgAA` must remain available until this module has
been deployed and all five managed panels show the expected production series.
After validating account, region, product-family scope, chart parity, detector
state, and notification routing, remove the manual dashboard from Splunk
Observability Cloud. Do not rename or reuse `Forge External Dependency Health`;
that dashboard is reserved for GitHub and regional SSM dependency probes.

Before removing the manual dashboard, verify:

1. Terraform created exactly one `Forge AWS Regional Platform Health`
   dashboard in the intended dashboard group.
1. All five panels return the expected series for every configured AWS region.
1. Account, region, and product-family selectors are restricted to the
   configured suggestions.
1. The three managed detector rules have the intended team and notification
   routing.
1. The manual and managed panels agree over the same time window.

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
| [signalfx_dashboard.aws_regional_health](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/dashboard) | resource |
| [signalfx_time_chart.build_queue_dlq_sends](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.build_queue_oldest_age](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.build_queue_visible_backlog](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.lambda_throttle_attempt_rate](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.lambda_throttle_count](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [terraform_data.dashboard_parent](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_dashboard_group"></a> [dashboard\_group](#input\_dashboard\_group) | Splunk Observability dashboard group ID. | `string` | n/a | yes |
| <a name="input_detector_id"></a> [detector\_id](#input\_detector\_id) | AWS regional platform detector ID linked to queue-health charts. | `string` | n/a | yes |
| <a name="input_dynamic_variables"></a> [dynamic\_variables](#input\_dynamic\_variables) | AWS account, region, and product-family dashboard variable definitions used to scope regional platform health. | <pre>list(object({<br/>    property               = string<br/>    alias                  = string<br/>    description            = string<br/>    values                 = list(string)<br/>    value_required         = bool<br/>    values_suggested       = list(string)<br/>    restricted_suggestions = bool<br/>  }))</pre> | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
