<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.27 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.23.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_github_webhook_relay_source"></a> [github\_webhook\_relay\_source](#module\_github\_webhook\_relay\_source) | ../../../integrations/github_webhook_relay_source | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.secret_reader](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.secret_reader_inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_kms_alias.github_webhook_relay](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.github_webhook_relay](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_secretsmanager_secret.github_webhook_relay](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.github_webhook_relay](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [random_id.github_webhook_relay_source_secret](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_iam_policy_document.secret_reader_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.secret_reader_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_github_webhook_relay"></a> [github\_webhook\_relay](#input\_github\_webhook\_relay) | Configuration for the (optional) webhook relay source module.<br/>If enabled=true we provision the API Gateway + source EventBridge forwarding rule.<br/>destination\_event\_bus\_name must already exist or be created in the destination account (or via the destination submodule run there). | <pre>object({<br/>    enabled                     = bool<br/>    destination_account_id      = optional(string)<br/>    destination_event_bus_name  = optional(string)<br/>    destination_region          = optional(string)<br/>    destination_reader_role_arn = optional(string)<br/>  })</pre> | <pre>{<br/>  "destination_account_id": "",<br/>  "destination_event_bus_name": "",<br/>  "destination_reader_role_arn": "",<br/>  "destination_region": "",<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR) | `string` | `"INFO"` | no |
| <a name="input_logging_retention_in_days"></a> [logging\_retention\_in\_days](#input\_logging\_retention\_in\_days) | Retention in days for CloudWatch Log Group for the Lambdas. | `number` | `30` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix for all resources | `string` | n/a | yes |
| <a name="input_secret_prefix"></a> [secret\_prefix](#input\_secret\_prefix) | Prefix for secret | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to created resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_source_secret_arn"></a> [source\_secret\_arn](#output\_source\_secret\_arn) | ARN of the GitHub webhook relay secret |
| <a name="output_source_secret_region"></a> [source\_secret\_region](#output\_source\_secret\_region) | AWS region the secret resides in |
| <a name="output_source_secret_role_arn"></a> [source\_secret\_role\_arn](#output\_source\_secret\_role\_arn) | ARN of IAM role permitted to read/decrypt the webhook relay secret |
<!-- END_TF_DOCS -->
