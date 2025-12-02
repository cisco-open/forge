<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.27 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.23.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_register_github_app_runner_group_lambda"></a> [register\_github\_app\_runner\_group\_lambda](#module\_register\_github\_app\_runner\_group\_lambda) | terraform-aws-modules/lambda/aws | 8.1.2 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.register_github_app_runner_group_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.register_github_app_runner_group_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.register_github_app_runner_group_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_lambda_permission.register_github_app_runner_group_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_iam_policy_document.register_github_app_runner_group_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_secretsmanager_secret.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret_version.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ghes_org"></a> [ghes\_org](#input\_ghes\_org) | GitHub organization (GHES or GitHub.com). | `string` | n/a | yes |
| <a name="input_github_api"></a> [github\_api](#input\_github\_api) | Base URL for the GitHub API (set to GHES API endpoint if using Enterprise). | `string` | `"https://api.github.com"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR) | `string` | `"INFO"` | no |
| <a name="input_logging_retention_in_days"></a> [logging\_retention\_in\_days](#input\_logging\_retention\_in\_days) | Retention in days for CloudWatch Log Group for the Lambdas. | `number` | `30` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix for all resources | `string` | n/a | yes |
| <a name="input_repository_selection"></a> [repository\_selection](#input\_repository\_selection) | Repository selection type: 'all' or 'selected'. | `string` | n/a | yes |
| <a name="input_runner_group_name"></a> [runner\_group\_name](#input\_runner\_group\_name) | Name of the GitHub Actions runner group to create/update and attach repositories to. | `string` | n/a | yes |
| <a name="input_secrets_prefix"></a> [secrets\_prefix](#input\_secrets\_prefix) | Prefix for all secrets | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to created resources. | `map(string)` | `{}` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
