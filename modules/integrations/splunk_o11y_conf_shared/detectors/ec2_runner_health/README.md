# Forge EC2 Runner Health Detectors

These detectors replace generic EC2 CPU, disk, and memory AutoDetect overlays
on the Forge runner dashboard with Forge-owned rules:

- CPU: Major above 90 percent for 10 minutes; clear below 70 percent for
  10 minutes.
- Disk: Major above 80 percent for 10 minutes; clear below 75 percent for
  10 minutes. Only writable `ext4` and `xfs` filesystems are monitored so
  read-only `squashfs` mounts do not create permanent false positives.
- Memory: Major above 90 percent for 10 minutes; clear below 80 percent for
  10 minutes.
- All detectors automatically resolve after a runner stops reporting for
  15 minutes.

Automatic resolution prevents incidents from remaining open after an
ephemeral runner terminates and its metric stream becomes inactive.

## Ownership and configuration

This is an internal submodule of `splunk_o11y_conf_shared`; deploy the parent
module rather than calling this directory directly. The parent scopes the
detectors to every configured dynamic metric property and the Forge tenant
names, and supplies the shared team notification routing.

The detector code does not know deployment-specific tag property names. It
uses the configured and suggested values for each supplied dynamic property.
Missing required values or a missing dynamic scope produce non-matching
filters, preventing an incomplete configuration from creating an
organization-wide detector.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_signalfx"></a> [signalfx](#requirement\_signalfx) | < 10.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_signalfx"></a> [signalfx](#provider\_signalfx) | < 10.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [signalfx_detector.ec2_runner_cpu](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/detector) | resource |
| [signalfx_detector.ec2_runner_disk](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/detector) | resource |
| [signalfx_detector.ec2_runner_memory](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/detector) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_detector_name_prefix"></a> [detector\_name\_prefix](#input\_detector\_name\_prefix) | Prefix to use for Splunk Observability detector names. | `string` | n/a | yes |
| <a name="input_detector_notifications"></a> [detector\_notifications](#input\_detector\_notifications) | Detector notification destinations. | `list(string)` | n/a | yes |
| <a name="input_dynamic_variables"></a> [dynamic\_variables](#input\_dynamic\_variables) | Dynamic metric property definitions used to scope the EC2 runner detectors. | <pre>list(object({<br/>    property               = string<br/>    alias                  = string<br/>    description            = string<br/>    values                 = list(string)<br/>    value_required         = bool<br/>    values_suggested       = list(string)<br/>    restricted_suggestions = bool<br/>  }))</pre> | n/a | yes |
| <a name="input_team"></a> [team](#input\_team) | Splunk Observability team ID. | `string` | n/a | yes |
| <a name="input_tenant_names"></a> [tenant\_names](#input\_tenant\_names) | Forge tenant names allowed to contribute runner health signals. | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_detector_ids"></a> [detector\_ids](#output\_detector\_ids) | Forge EC2 runner health detector IDs for dashboard alert overlays. |
<!-- END_TF_DOCS -->
