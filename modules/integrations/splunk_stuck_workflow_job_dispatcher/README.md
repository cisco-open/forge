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
`github.github-delivery`. The receiver passes that field to the worker as
`github_delivery`. If `aws_region` is missing, the receiver tries to parse the
region from the SQS queue URL.

## Logs

API Gateway access logs are written to `/aws/apigateway/<name_prefix>`. These
logs include the request path, route key, status, integration status, response
latency, and API Gateway error fields so rejected or unrouted requests can be
found without a Lambda invocation.

Receiver Lambda logs are written to `/aws/lambda/<name_prefix>`. Requests with a
missing or invalid webhook token return HTTP 403 and are logged as
`request_rejected` with request metadata such as source IP, method, path, route
key, user agent, and token length. The token value is never logged.

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

<!-- BEGIN_TF_DOCS -->

<!-- END_TF_DOCS -->
