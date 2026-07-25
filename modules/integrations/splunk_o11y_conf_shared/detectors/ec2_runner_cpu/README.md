# Forge EC2 Runner CPU Detector

This detector replaces the generic EC2 CPU autodetect overlay on the Forge
runner dashboard with a Forge-owned rule:

- Major when a runner remains above 90 percent CPU for 10 minutes.
- Clear after CPU remains below 70 percent for 10 minutes.
- Automatically resolve after a runner stops reporting for 15 minutes.

Automatic resolution prevents incidents from remaining open after an
ephemeral runner terminates and its metric stream becomes inactive.

## Ownership and configuration

This detector is an internal submodule of `splunk_o11y_conf_shared`; deploy the
parent module rather than calling this directory directly. The parent scopes
the detector to configured Forge AWS accounts, regions, product families, and
tenant names and supplies the shared team notification routing.

Missing scope values produce non-matching filters, preventing an incomplete
configuration from creating an organization-wide detector.

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
| [signalfx_detector.ec2_runner_cpu](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/detector) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_detector_name_prefix"></a> [detector\_name\_prefix](#input\_detector\_name\_prefix) | Prefix to use for Splunk Observability detector names. | `string` | n/a | yes |
| <a name="input_detector_notifications"></a> [detector\_notifications](#input\_detector\_notifications) | Detector notification destinations. | `list(string)` | n/a | yes |
| <a name="input_dynamic_variables"></a> [dynamic\_variables](#input\_dynamic\_variables) | AWS account, region, and product-family definitions used to scope the EC2 runner detector. | <pre>list(object({<br/>    property               = string<br/>    alias                  = string<br/>    description            = string<br/>    values                 = list(string)<br/>    value_required         = bool<br/>    values_suggested       = list(string)<br/>    restricted_suggestions = bool<br/>  }))</pre> | n/a | yes |
| <a name="input_team"></a> [team](#input\_team) | Splunk Observability team ID. | `string` | n/a | yes |
| <a name="input_tenant_names"></a> [tenant\_names](#input\_tenant\_names) | Forge tenant names allowed to contribute runner CPU signals. | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_detector_id"></a> [detector\_id](#output\_detector\_id) | Forge EC2 runner CPU detector ID for dashboard alert overlays. |
<!-- END_TF_DOCS -->
