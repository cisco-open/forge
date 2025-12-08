# GitHub Webhook Relay Destination Receivers Example

This example composes the `github_webhook_relay_destination` Forge integration module with one or more Lambda receiver functions. It demonstrates how to deploy a Lambda that reacts to forwarded GitHub webhook events (via EventBridge) and can relay messages (e.g. to Webex) using a secure bot token stored in AWS Secrets Manager.

## Overview

Resources provisioned:
- EventBridge destination bus + rules (via `github_webhook_relay_destination` module)
- IAM secret reader role for controlled access to the bot token (optional depending on `reader_config`)
- Lambda function `webex_webhook_relay` (Python 3.12) with log retention and environment wiring
- Required permissions and tagging

Event flow:
1. GitHub webhook is ingested upstream (outside this example) and forwarded onto an EventBridge bus.
2. Destination bus rules match the desired events (here: `detail.action == completed`).
3. The matched event triggers the `webex_webhook_relay` Lambda.
4. The Lambda reads the Webex bot token from Secrets Manager and performs the relay logic.

## Requirements

Before applying this example you must have:
- OpenTofu `~> 1.10` (or Terraform compatible if migrating) and AWS provider `~> 6.0`.
- AWS credentials/profile able to create EventBridge, Lambda, IAM, and Secrets Manager resources.
- Existing GitHub webhook relay pipeline that sends events to the source account & bus referenced.
- A Secrets Manager secret containing the Webex bot token at the exact name:
  - `/cicd/common/webex_webhook_relay_bot_token`
- (Optional) A source secret reader role / secret if cross-account fetching is enabled via `reader_config`.

## Mandatory Secret

The Lambda `webex_webhook_relay` expects an environment variable `WEBEX_BOT_TOKEN_SECRET_NAME` which points to the secret name. This example sets it to `/cicd/common/webex_webhook_relay_bot_token`.

Secret value format (JSON string):

```json
{
  "token": "<webex_bot_token>",
  "room_id": "<webex_room_id>"
}
```

Both `token` and `room_id` keys are required. The function will prepend `Bearer ` to `token` automatically if not present.


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.25 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.13.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.25.0 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.13.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_webex"></a> [webex](#module\_webex) | terraform-aws-modules/lambda/aws | 8.1.2 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.webex](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_kms_alias.webex_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.webex](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_secretsmanager_secret.cicd_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.cicd_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [time_sleep.wait_60_seconds](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_iam_policy_document.secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_secretsmanager_random_password.secret_seeds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_random_password) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Default AWS region. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR) | `string` | `"INFO"` | no |
| <a name="input_logging_retention_in_days"></a> [logging\_retention\_in\_days](#input\_logging\_retention\_in\_days) | Number of days to retain logs in CloudWatch. | `number` | `3` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | n/a |
<!-- END_TF_DOCS -->
