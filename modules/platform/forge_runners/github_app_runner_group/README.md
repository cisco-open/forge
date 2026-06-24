# GitHub App Runner Group Registration

This module keeps the GitHub App installation and runner group aligned with the tenant repository selection.

## Why This Module Exists

Runner groups are the GitHub-side boundary that keeps one tenant job from consuming another tenant runner. Forge reconciles that mapping automatically so onboarding repositories does not require manual GitHub UI work.

## What It Manages

- A scheduled Lambda for runner group registration/reconciliation.
- CloudWatch logs and EventBridge schedule.
- IAM permissions and GitHub App configuration needed by the Lambda.
- Inputs for GHES/GitHub URL, organization, runner group, and repository selection.

## Operational Notes

- If jobs stay queued even though runners exist, check labels and runner-group registration together.
- `repository_selection` must match the GitHub App installation policy: `all` or `selected`.
- This module changes GitHub-side routing, so treat failures as tenant-impacting.

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

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_register_github_app_runner_group_lambda"></a> [register\_github\_app\_runner\_group\_lambda](#module\_register\_github\_app\_runner\_group\_lambda) | terraform-aws-modules/lambda/aws | 8.8.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_event_rule.register_github_app_runner_group_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.register_github_app_runner_group_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.register_github_app_runner_group_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_lambda_permission.register_github_app_runner_group_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_iam_policy_document.register_github_app_runner_group_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_ghes_org"></a> [ghes\_org](#input\_ghes\_org) | GitHub organization (GHES or GitHub.com). | `string` | n/a | yes |
| <a name="input_github_api"></a> [github\_api](#input\_github\_api) | Base URL for the GitHub API (set to GHES API endpoint if using Enterprise). | `string` | `"https://api.github.com"` | no |
| <a name="input_github_app"></a> [github\_app](#input\_github\_app) | GitHub App configuration | <pre>object({<br/>    key_base64_ssm = object({<br/>      arn = string<br/>    })<br/>    id_ssm = object({<br/>      arn = string<br/>    })<br/>    installation_id_ssm = object({<br/>      arn = string<br/>    })<br/>  })</pre> | n/a | yes |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR) | `string` | `"INFO"` | no |
| <a name="input_logging_retention_in_days"></a> [logging\_retention\_in\_days](#input\_logging\_retention\_in\_days) | Retention in days for CloudWatch Log Group for the Lambdas. | `number` | `30` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix for all resources | `string` | n/a | yes |
| <a name="input_repository_selection"></a> [repository\_selection](#input\_repository\_selection) | Repository selection type: 'all' or 'selected'. | `string` | n/a | yes |
| <a name="input_runner_group_name"></a> [runner\_group\_name](#input\_runner\_group\_name) | Name of the GitHub Actions runner group to create/update and attach repositories to. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to created resources. | `map(string)` | `{}` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
