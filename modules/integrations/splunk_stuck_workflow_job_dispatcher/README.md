# Splunk stuck workflow job dispatcher

This module creates a Splunk saved-search alert for Forge `workflow_job` events
that remain queued after a dispatch log is seen. The alert posts to an AWS HTTP
API endpoint. The receiver Lambda validates a path token, normalizes the Splunk
result, and writes one pending work item to DynamoDB. DynamoDB Streams invokes a
worker Lambda that performs GitHub App webhook redelivery directly.

## Flow

```text
Splunk saved search
  -> API Gateway
  -> receiver Lambda
  -> DynamoDB dedupe/work item
  -> DynamoDB Streams
  -> worker Lambda
  -> GitHub App webhook redelivery API
```

## What The Worker Does

For each stuck job, the worker:

1. Loads the generated tenant mapping JSON from one or more SSM String
   parameters under `/forge/<name_prefix>/tenant-configs/<index>`. Terraform
   splits the JSON into sub-4 KB chunks and passes only the SSM prefix/count to
   Lambda.
2. Selects the Forge tenant configuration using `tenant` and `aws_region`.
   Each matching mapping entry provides the `deployment_prefix` used to read
   GitHub App credentials from SSM. Each tenant carries `gh_config.ghes_url`, so
   the module can derive `github_api` with
   `ghes_url == "" ? "https://api.github.com" : "${ghes_url}/api/v3"`.
3. Reads GitHub App credentials from SSM Parameter Store:
   - `/forge/<tenant>-<region-code>-sl/github_app_key`
   - `/forge/<tenant>-<region-code>-sl/github_app_client_id`
   - `/forge/<tenant>-<region-code>-sl/github_app_id`
4. Creates a GitHub App JWT in Lambda.
5. Redelivers the deliveries from `github.github-delivery`. Numeric values are
   used directly; GUID values are resolved to numeric delivery IDs through the
   GitHub App deliveries list API before the redelivery attempt is sent.

The GitHub redelivery API still requires the numeric delivery ID in
`POST /app/hook/deliveries/{delivery_id}/attempts`; the worker performs that
lookup when Splunk sends the `github.github-delivery` GUID.

## Splunk Alert

The saved search runs every minute by default, searches the last 24 hours, and
triggers once per scheduled run when stuck jobs exist. The search collapses all
matching stuck jobs into one Splunk webhook row with a JSON `results` array, and
the receiver queues one DynamoDB work item per nested result. Duplicate alert
actions are suppressed by Splunk for the configured suppression window, and
duplicate jobs are suppressed by the DynamoDB item key in AWS.

The alert query keeps the same core logic as the Forge dashboard query and adds
`aws_region` to the result table so the worker can find the right tenant SSM
parameters. It groups stuck jobs by workflow job ID, keeps the Forge tenant and
AWS region as result values, and passes `github_delivery` from
`github.github-delivery`. It also carries GitHub workflow context from the
webhook log, including `runId`, `runAttempt`, `runUrl`, `workflowName`,
`headSha`, `headBranch`, and `created_at`. The receiver normalizes GitHub
workflow-job labels into `runner_labels` and stores them with the work item so a
later compatibility check can compare stuck-job labels with active EC2 runner
labels before redelivery. The receiver passes `github_delivery` to the worker as
the redelivery source. `aws_region` is required in the alert payload and is not
inferred from the SQS queue URL.

## Logs

API Gateway access logs are written to `/aws/apigateway/<name_prefix>`. These
logs include the request path, route key, status, integration status, response
latency, and API Gateway error fields so rejected or unrouted requests can be
found without a Lambda invocation.

Receiver Lambda logs are written to `/aws/lambda/<name_prefix>`. Requests with a
missing or invalid webhook token return HTTP 403 and are logged as
`request_rejected` with request metadata such as source IP, method, path, route
key, user agent, and token length. The token value is never logged.

The shared `splunk_cloud_conf_shared` module owns the dispatcher Splunk
transforms, dashboards, and `props/aws:cloudwatchlogs` report bindings. Those
shared assets extract dispatcher fields such as `stuck_dispatcher_tenant`,
`stuck_dispatcher_repository`, `stuck_dispatcher_workflow_job_id`, and runner
capacity counters. The dashboards also parse dispatcher fields inline with
`rex`, so they keep working before those transforms are visible in Splunk
search.

## Example Module Call

```hcl
module "splunk_stuck_workflow_job_dispatcher" {
  source = "path/to/modules/integrations/splunk_stuck_workflow_job_dispatcher"

  aws_profile  = var.aws_profile
  aws_region   = var.aws_region
  default_tags = var.default_tags
  tags         = var.tags
  splunk_conf  = var.splunk_conf

  redelivery_config = {
    tenant_configs = [
      {
        tenant = "cnhe"
        gh_config = {
          ghes_url = ""
        }
        prefixes = [
          {
            aws_region        = "us-west-2"
            deployment_prefix = "cnhe-usw2-sl"
          }
        ]
      }
    ]
  }
}
```

## Forge Context

This module closes a specific operational loop in Forge: a queued GitHub Actions job may be stuck because the original webhook delivery did not result in runner creation. Splunk already has the workflow and dispatch evidence, so the saved search turns that evidence into a controlled redelivery request instead of a manual GitHub UI action.

The tenant mapping is stored in SSM chunks because large multi-tenant configuration does not fit comfortably in Lambda environment variables. When changing tenant discovery, verify both the saved search fields and the Lambda-side mapping lookup.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.47 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.7 |
| <a name="requirement_splunk"></a> [splunk](#requirement\_splunk) | >= 1.4.30 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.52.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.0 |
| <a name="provider_splunk"></a> [splunk](#provider\_splunk) | 1.5.3 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_dispatcher"></a> [dispatcher](#module\_dispatcher) | terraform-aws-modules/lambda/aws | 8.8.0 |
| <a name="module_worker"></a> [worker](#module\_worker) | terraform-aws-modules/lambda/aws | 8.8.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_apigatewayv2_api.splunk](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api) | resource |
| [aws_apigatewayv2_integration.dispatcher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration) | resource |
| [aws_apigatewayv2_route.splunk_webhook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route) | resource |
| [aws_apigatewayv2_stage.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_stage) | resource |
| [aws_cloudwatch_log_group.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.dispatcher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_dynamodb_table.dedupe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_lambda_event_source_mapping.worker_from_dedupe_stream](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_permission.apigw_invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_ssm_parameter.tenant_configs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [random_password.webhook_token](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [splunk_configs_conf.stuck_workflow_job_dispatcher](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.dispatcher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_secretsmanager_secret.splunk_cloud_api_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret_version.splunk_cloud_api_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Default AWS region. | `string` | n/a | yes |
| <a name="input_dedupe_ttl_seconds"></a> [dedupe\_ttl\_seconds](#input\_dedupe\_ttl\_seconds) | Seconds to suppress duplicate redelivery work for the same workflow job. | `number` | `1800` | no |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of default tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR). | `string` | `"INFO"` | no |
| <a name="input_logging_retention_in_days"></a> [logging\_retention\_in\_days](#input\_logging\_retention\_in\_days) | Number of days to retain Lambda and API logs. | `number` | `14` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for created AWS resources. | `string` | `"forge-stuck-workflow-job-dispatcher"` | no |
| <a name="input_redelivery_config"></a> [redelivery\_config](#input\_redelivery\_config) | GitHub App webhook redelivery behavior.<br/><br/>Nested attributes:<br/>- tenant\_configs: Tenant-specific GitHub Enterprise and deployment prefix mappings.<br/>- tenant\_configs.tenant: Forge tenant name from Splunk logs.<br/>- tenant\_configs.github\_api\_version: Optional GitHub API version header; defaults to 2022-11-28.<br/>- tenant\_configs.gh\_config: GitHub deployment settings for the tenant.<br/>- tenant\_configs.gh\_config.ghes\_url: GitHub Enterprise Server base URL; empty string selects github.com.<br/>- tenant\_configs.prefixes: AWS region-specific deployment prefix mappings for the tenant.<br/>- tenant\_configs.prefixes.aws\_region: AWS region where the tenant GitHub App SSM parameters are stored.<br/>- tenant\_configs.prefixes.deployment\_prefix: SSM prefix under /forge/<deployment\_prefix>/ for GitHub App credentials. | <pre>object({<br/>    tenant_configs = optional(list(object({<br/>      tenant             = string<br/>      github_api_version = optional(string)<br/>      gh_config = object({<br/>        ghes_url = string<br/>      })<br/>      prefixes = list(object({<br/>        aws_region        = string<br/>        deployment_prefix = string<br/>      }))<br/>    })), [])<br/>  })</pre> | `{}` | no |
| <a name="input_splunk_alert"></a> [splunk\_alert](#input\_splunk\_alert) | Splunk saved-search alert configuration.<br/><br/>Nested attributes:<br/>- name: Splunk saved-search name.<br/>- description: Splunk saved-search description.<br/>- disabled: Whether to create the saved search in a disabled state.<br/>- cron\_schedule: Cron schedule for evaluating the saved search.<br/>- dispatch\_earliest\_time: Earliest Splunk search time for each alert run.<br/>- dispatch\_latest\_time: Latest Splunk search time for each alert run.<br/>- stuck\_minutes\_threshold: Minimum queued duration before redelivery is triggered.<br/>- suppress\_period: Splunk alert suppression window for duplicate stuck-job results. | <pre>object({<br/>    name                    = optional(string, "Forge stuck workflow_job dispatcher")<br/>    description             = optional(string, "Queues GitHub App webhook redelivery when Forge workflow_job queued events stay stuck after dispatch.")<br/>    disabled                = optional(bool, false)<br/>    cron_schedule           = optional(string, "*/1 * * * *")<br/>    dispatch_earliest_time  = optional(string, "-24h")<br/>    dispatch_latest_time    = optional(string, "now")<br/>    stuck_minutes_threshold = optional(number, 5)<br/>    suppress_period         = optional(string, "30m")<br/>  })</pre> | `{}` | no |
| <a name="input_splunk_conf"></a> [splunk\_conf](#input\_splunk\_conf) | Splunk Cloud connection, ACL, and Forge index settings.<br/><br/>Nested attributes:<br/>- splunk\_cloud: Splunk Cloud host name used by the Splunk provider.<br/>- acl: Access control settings for the saved search.<br/>- acl.app: Splunk app that owns the saved search.<br/>- acl.owner: Splunk owner for the saved search.<br/>- acl.sharing: Splunk sharing scope for the saved search ACL.<br/>- acl.read: Splunk roles allowed to read the saved search.<br/>- acl.write: Splunk roles allowed to update the saved search.<br/>- index: Splunk index containing Forge CICD webhook and dispatch logs.<br/>- tenant\_names: Optional tenant allow-list retained for compatibility with shared Splunk configuration. | <pre>object({<br/>    splunk_cloud = string<br/>    acl = object({<br/>      app     = string<br/>      owner   = string<br/>      sharing = string<br/>      read    = list(string)<br/>      write   = list(string)<br/>    })<br/>    index        = string<br/>    tenant_names = optional(list(string), [])<br/>  })</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_api_endpoint"></a> [api\_endpoint](#output\_api\_endpoint) | Base HTTP API endpoint for the Splunk alert webhook receiver. |
| <a name="output_api_log_group_name"></a> [api\_log\_group\_name](#output\_api\_log\_group\_name) | CloudWatch log group containing API Gateway HTTP API access logs. |
| <a name="output_dedupe_table_name"></a> [dedupe\_table\_name](#output\_dedupe\_table\_name) | DynamoDB table used to suppress duplicate dispatches. |
| <a name="output_receiver_lambda_function_arn"></a> [receiver\_lambda\_function\_arn](#output\_receiver\_lambda\_function\_arn) | Splunk webhook receiver Lambda ARN. |
| <a name="output_receiver_lambda_log_group_name"></a> [receiver\_lambda\_log\_group\_name](#output\_receiver\_lambda\_log\_group\_name) | CloudWatch log group containing Splunk webhook receiver Lambda logs. |
| <a name="output_saved_search_name"></a> [saved\_search\_name](#output\_saved\_search\_name) | Splunk saved search alert name. |
| <a name="output_splunk_webhook_url"></a> [splunk\_webhook\_url](#output\_splunk\_webhook\_url) | Full Splunk webhook URL, including the shared path token. |
| <a name="output_worker_lambda_function_arn"></a> [worker\_lambda\_function\_arn](#output\_worker\_lambda\_function\_arn) | GitHub App redelivery worker Lambda ARN. |
| <a name="output_worker_lambda_log_group_name"></a> [worker\_lambda\_log\_group\_name](#output\_worker\_lambda\_log\_group\_name) | CloudWatch log group containing GitHub App redelivery worker Lambda logs. |
<!-- END_TF_DOCS -->
