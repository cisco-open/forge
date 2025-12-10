<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.25 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.25.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_webex_webhook_relay"></a> [webex\_webhook\_relay](#module\_webex\_webhook\_relay) | ./webex_webhook_relay | n/a |
| <a name="module_webhook_relay_destination"></a> [webhook\_relay\_destination](#module\_webhook\_relay\_destination) | ../github_webhook_relay_destination | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile (i.e., generated via 'sl aws session generate') to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Default AWS region. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_enable_webex_webhook_relay"></a> [enable\_webex\_webhook\_relay](#input\_enable\_webex\_webhook\_relay) | Enable Webex webhook relay. | `bool` | n/a | yes |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR) | `string` | `"INFO"` | no |
| <a name="input_logging_retention_in_days"></a> [logging\_retention\_in\_days](#input\_logging\_retention\_in\_days) | Number of days to retain logs. | `number` | `3` | no |
| <a name="input_reader_config"></a> [reader\_config](#input\_reader\_config) | Configuration for the reader to fetch secrets. | <pre>object({<br/>    enable_secret_fetch    = bool<br/>    source_secret_role_arn = string<br/>    source_secret_arn      = string<br/>    source_secret_region   = string<br/>  })</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_webhook_relay_destination_config"></a> [webhook\_relay\_destination\_config](#input\_webhook\_relay\_destination\_config) | Configuration for webhook relay destination. | <pre>object({<br/>    name_prefix                = string<br/>    destination_event_bus_name = string<br/>    source_account_id          = string<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | Local role ARN. |
| <a name="output_webhook"></a> [webhook](#output\_webhook) | Webhook relay and secret fetched from source account. |
<!-- END_TF_DOCS -->
