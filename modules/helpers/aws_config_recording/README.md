# AWS Config Recording

This module enables continuous AWS Config recording for caller-selected AWS resource types.

## What It Manages

- A configuration recorder for the resource types supplied through `recorded_resource_types`.
- An IAM role with the AWS managed Config recorder policy.
- A delivery channel targeting the existing bucket supplied through `delivery_bucket_name`.
- An enabled recorder status.

## Operational Notes

- Deploy one instance of this module per AWS account and Region where configuration recording is required.
- The account and Region must not already have a customer-managed configuration recorder or delivery channel with conflicting names.
- The default IAM role name includes `aws_region`, preventing global IAM name collisions when the module is deployed in multiple Regions.
- The delivery bucket can be in another Region or account.
- Manage the bucket and its AWS Config permissions externally; this module never creates or changes the bucket or its policy.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.47 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.47 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_config_configuration_recorder.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_configuration_recorder) | resource |
| [aws_config_configuration_recorder_status.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_configuration_recorder_status) | resource |
| [aws_config_delivery_channel.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_delivery_channel) | resource |
| [aws_iam_role.config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.config_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Default AWS region. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_delivery_bucket_name"></a> [delivery\_bucket\_name](#input\_delivery\_bucket\_name) | Name of the existing S3 bucket that receives AWS Config data. The bucket can be in another Region or account. | `string` | n/a | yes |
| <a name="input_delivery_channel_name"></a> [delivery\_channel\_name](#input\_delivery\_channel\_name) | Name of the AWS Config delivery channel. | `string` | `"default"` | no |
| <a name="input_iam_role_name"></a> [iam\_role\_name](#input\_iam\_role\_name) | Name of the IAM role used by AWS Config. Defaults to forge-aws-config-recorder-<aws\_region>. | `string` | `null` | no |
| <a name="input_recorded_resource_types"></a> [recorded\_resource\_types](#input\_recorded\_resource\_types) | AWS Config resource types to record, using identifiers such as AWS::EC2::Instance. | `set(string)` | n/a | yes |
| <a name="input_recorder_name"></a> [recorder\_name](#input\_recorder\_name) | Name of the AWS Config configuration recorder. | `string` | `"default"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of additional tags to apply to resources. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_configuration_recorder_name"></a> [configuration\_recorder\_name](#output\_configuration\_recorder\_name) | Name of the enabled AWS Config configuration recorder. |
| <a name="output_delivery_bucket_name"></a> [delivery\_bucket\_name](#output\_delivery\_bucket\_name) | Name of the S3 bucket receiving AWS Config snapshots and history. |
| <a name="output_recorded_resource_types"></a> [recorded\_resource\_types](#output\_recorded\_resource\_types) | AWS resource types recorded by AWS Config. |
<!-- END_TF_DOCS -->
