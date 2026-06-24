# AWS Opt-In Regions

This module enables configured opt-in AWS regions for an account.

## Why This Module Exists

Forge can run tenants across regions, but AWS opt-in regions must be enabled before regional infrastructure can be planned or applied there. Making that step code-driven keeps account bootstrap repeatable.

## What It Manages

- AWS account region enablement for each entry in `opt_in_regions`.
- Provider and tagging inputs needed by the account bootstrap flow.

## Operational Notes

- Region opt-in can take time to complete in AWS; plan downstream regional applies accordingly.
- Use this only for regions that the organization has approved for Forge workloads.
- This module does not create VPCs, subnets, or runners in the region.

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
| [aws_account_region.enabled_regions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/account_region) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Default AWS region. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_opt_in_regions"></a> [opt\_in\_regions](#input\_opt\_in\_regions) | List of opt-in AWS regions to enable | `list(string)` | `[]` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
