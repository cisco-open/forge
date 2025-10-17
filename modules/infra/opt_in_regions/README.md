<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.90 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.17.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_account_region.enabled_regions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/account_region) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Default AWS region. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_opt_in_regions"></a> [opt\_in\_regions](#input\_opt\_in\_regions) | List of opt-in AWS regions to enable | `list(string)` | `[]` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
