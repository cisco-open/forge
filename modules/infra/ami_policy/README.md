# AMI Policy

This module applies account-level guardrails around AMI and EBS lifecycle management for Forge runner images.

## Why This Module Exists

Forge runners are intentionally disposable, but the images behind them are long-lived platform assets. This module keeps the AWS account ready for encrypted runner volumes and automated AMI lifecycle cleanup so image hygiene does not become manual work.

## What It Manages

- Enables EBS encryption by default in the target region.
- Creates the Data Lifecycle Manager role used by AMI lifecycle policies.
- Defines lifecycle policy permissions for AMI and snapshot cleanup.
- Applies the common Forge tags used for ownership and cost reporting.

## Operational Notes

- Use this in accounts that build, store, or operate runner AMIs.
- Review lifecycle timing before applying it to an account that also hosts non-Forge AMIs.
- Encryption-by-default is account and region scoped, so treat this module as a regional foundation step.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.47 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.51.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_dlm_lifecycle_policy.dlm_lifecycle](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dlm_lifecycle_policy) | resource |
| [aws_ebs_encryption_by_default.gpol_encrypt_ebs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_encryption_by_default) | resource |
| [aws_iam_role.dlm_lifecycle_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.dlm_lifecycle](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Assuming single region for now. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
