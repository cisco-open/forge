# AMI Sharing

This module shares selected runner AMIs with one or more AWS accounts.

## Why This Module Exists

Forge separates image building from runner execution. The platform can produce hardened, tested runner images in one account and grant launch permission to the accounts that run EC2-based GitHub Actions jobs.

## What It Manages

- Looks up AMIs by name and state filters.
- Grants AMI launch permission to the configured AWS account IDs.
- Keeps AMI distribution as code instead of a console operation.

## Operational Notes

- The filters should be narrow enough to select only intended runner images.
- Sharing an AMI does not copy its KMS permissions; encrypted AMIs also require compatible KMS access.
- Use this with the EC2 runner modules when runner accounts consume centrally built images.

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
| [aws_ami_launch_permission.share_amis](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ami_launch_permission) | resource |
| [aws_ami.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_ids"></a> [account\_ids](#input\_account\_ids) | List of AWS accounts to share AMIs with | `list(string)` | n/a | yes |
| <a name="input_ami_name_filters"></a> [ami\_name\_filters](#input\_ami\_name\_filters) | AMI name filter to use to find AMIs to share | `list(string)` | n/a | yes |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Assuming single region for now. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
