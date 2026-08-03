# Splunk dependency monitor

This regional integration deploys a scheduled Lambda that discovers the Forge
tenants deployed in its AWS region and verifies each tenant's real
Forge-to-GitHub path.

For every tenant in the current AWS region, the Lambda:

1. Discovers the existing platform-owned
   `/forge/<deployment_prefix>/github_ghes_org` parameters in regional SSM.
2. Reads the existing GitHub App SecureString parameters and GitHub routing
   parameters from the discovered deployment prefix.
3. Creates a short-lived GitHub App JWT using the client ID, falling back to
   the numeric app ID.
4. Exchanges the JWT and installation ID for an installation token.
5. Calls the tenant's configured
   `GET /orgs/<org>/actions/runners?per_page=1` endpoint.
6. Batches structured probe results for Splunk Cloud HEC.
7. Batches low-cardinality datapoints for SSM access, GitHub authentication,
   organization API availability, latency, and GitHub rate-limit budget.
8. Sends the event and metric batches directly to Splunk Cloud and Splunk
   Observability.

Delivery intentionally bypasses CloudWatch custom metrics:

`Lambda -> Splunk Cloud HEC`

`Lambda -> Splunk Observability Cloud /v2/datapoint`

This follows the same HTTP contracts as `splunk_aws_billing`:

- Splunk Cloud receives gzip-compressed, newline-delimited HEC events with
  `Authorization: Splunk <token>`.
- Splunk Observability receives `{"gauge": [...]}` with `X-SF-TOKEN`.

Terraform reads the integration-specific tokens from the regional Secrets
Manager replicas and supplies them to the Lambda environment, matching the
existing billing integration:

- `/cicd/common/splunk_cloud_hec_token_dependency_monitor`
- `/cicd/common/splunk_o11y_ingest_token_dependency_monitor`

The tokens are never logged. CloudWatch retains sanitized operational logs
only.

The private key, JWT, installation token, client ID, app ID, installation ID,
and SSM values are never logged or placed in metric dimensions.

The platform `forge_runners` module already creates these reusable, non-secret
regional SSM parameters beside the GitHub App parameters:

- `/forge/<deployment_prefix>/github_ghes_url` from
  `deployment_config.github.ghes_url` (`https://github.com` when empty)
- `/forge/<deployment_prefix>/github_ghes_org` from
  `deployment_config.github.ghes_org`

On every scheduled invocation, the dependency-monitor Lambda uses
`DescribeParameters` with the `/forge/` name prefix and selects only parameters
whose name ends in `/github_ghes_org`. It derives each deployment prefix from
the parameter path and reads the existing parameter's `TenantName` tag for the
tenant dimension, falling back to the GitHub organization value when the tag is
absent. A newly deployed regional tenant is
therefore discovered without changing or reapplying this module.

The module creates no tenant-discovery parameters. The discovery call returns
metadata and reads the existing non-secret organization parameter. The Lambda
only decrypts the GitHub App parameters explicitly allowed by its IAM policy. A
`github_ghes_url` of `https://github.com` selects `https://api.github.com`; a
configured GHES URL selects its `/api/v3` endpoint. This module only reads
platform-owned parameters; it does not create or own tenant configuration.

Deploy one module instance per Forge AWS region. SSM Parameter Store is
regional, and all boto3 clients are pinned to the Lambda's `AWS_REGION`, so a
regional monitor only discovers and probes Forge deployments in that region.

```hcl
module "splunk_dependency_monitor" {
  source = "path/to/modules/integrations/splunk_dependency_monitor"

  aws_profile        = var.aws_profile
  aws_region         = "us-west-2"
  default_tags       = var.default_tags
  github_api_version = "2022-11-28"

  splunk_dependency_monitor_config = {
    splunk_hec_url     = "https://http-inputs-example.splunkcloud.com:443/services/collector"
    splunk_index       = "srea-forge-prod-index"
    splunk_metrics_url = "https://ingest.us1.observability.splunkcloud.com/v2/datapoint"
  }
}
```

The related tenant-level Splunk Observability detectors are defined under
`splunk_o11y_conf_shared/detectors/dependency_probes` and are always created for
the dependency-probe tenants configured in the shared Observability module.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.47 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.57.1 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_dependency_monitor"></a> [dependency\_monitor](#module\_dependency\_monitor) | terraform-aws-modules/lambda/aws | 8.8.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_event_rule.dependency_monitor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.dependency_monitor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.dependency_monitor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_lambda_permission.eventbridge_invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_servicecatalogappregistry_application.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/servicecatalogappregistry_application) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.dependency_monitor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_secretsmanager_secret.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret_version.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region in which to run the dependency probe. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of default tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_github_api_version"></a> [github\_api\_version](#input\_github\_api\_version) | GitHub REST API version sent by every regional dependency probe. | `string` | `"2022-11-28"` | no |
| <a name="input_github_timeout_seconds"></a> [github\_timeout\_seconds](#input\_github\_timeout\_seconds) | Timeout for each GitHub API request. | `number` | `10` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Lambda log level. | `string` | `"INFO"` | no |
| <a name="input_logging_retention_in_days"></a> [logging\_retention\_in\_days](#input\_logging\_retention\_in\_days) | Number of days to retain dependency-probe Lambda logs. | `number` | `3` | no |
| <a name="input_schedule_expression"></a> [schedule\_expression](#input\_schedule\_expression) | EventBridge schedule for tenant dependency probes. | `string` | `"cron(*/5 * * * ? *)"` | no |
| <a name="input_splunk_dependency_monitor_config"></a> [splunk\_dependency\_monitor\_config](#input\_splunk\_dependency\_monitor\_config) | Splunk Cloud HEC and Splunk Observability metric-ingest configuration. | <pre>object({<br/>    splunk_hec_url     = string<br/>    splunk_index       = string<br/>    splunk_metrics_url = string<br/>  })</pre> | n/a | yes |
| <a name="input_splunk_http_timeout_seconds"></a> [splunk\_http\_timeout\_seconds](#input\_splunk\_http\_timeout\_seconds) | Timeout for batched Splunk Cloud and Splunk O11y HTTP requests. | `number` | `10` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of additional tags to apply to resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | ARN of the regional dependency-monitor Lambda. |
| <a name="output_lambda_log_group_name"></a> [lambda\_log\_group\_name](#output\_lambda\_log\_group\_name) | CloudWatch log group containing dependency-probe results. |
<!-- END_TF_DOCS -->
