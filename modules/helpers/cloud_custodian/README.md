# Cloud Custodian Role

This module creates the IAM role and policy used by Cloud Custodian automation in Forge-managed AWS accounts.

## Why This Module Exists

Forge relies on automation to keep multi-tenant runner infrastructure clean and compliant. Cloud Custodian is one of the account-level tools used for inspection and remediation, so its role needs to be reproducible and consistently trusted.

## What It Manages

- An IAM role that the configured Forge role can assume.
- A policy document for the Cloud Custodian actions required in the account.
- Policy attachment and standard Forge tags.

## Operational Notes

- Keep the trust principal aligned with the platform role that actually runs custodian policies.
- Policy scope should be reviewed when new remediation policies are added.
- This module prepares access; it does not define the custodian policy files themselves.

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
| [aws_iam_policy.cloud_custodian_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.cloud_custodian](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.attach_cloud_custodian_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.assume_role_for_cloud_custodian](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cloud_custodian_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Assuming single region for now. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_forge_role_arn"></a> [forge\_role\_arn](#input\_forge\_role\_arn) | ARN of the role to assume for Cloud Custodian. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
