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

1. Selects the Forge tenant configuration from `redelivery_config.tenant_configs`
   using `tenant`, `region`, and optional `vpc_alias` or `region_alias`.
   If Splunk omits an alias, the worker accepts a single matching prefix and
   fails closed when multiple prefixes match. Each tenant carries
   `gh_config.ghes_url`, so the module can derive `github_api` with
   `ghes_url == "" ? "https://api.github.com" : "${ghes_url}/api/v3"`.
2. Reads GitHub App credentials from SSM Parameter Store:
   - `/forge/<tenant>-<region-code>-sl/github_app_key`
   - `/forge/<tenant>-<region-code>-sl/github_app_client_id`
   - `/forge/<tenant>-<region-code>-sl/github_app_id`
3. Creates a GitHub App JWT in Lambda.
4. Redelivers the numeric `delivery_ids` parsed by Splunk from the dispatch
   log `--delivery-id` argument.

The worker does not list GitHub deliveries or resolve delivery GUIDs. Splunk
must pass the numeric delivery ID required by
`POST /app/hook/deliveries/{delivery_id}/attempts`.

## Splunk Alert

The saved search runs every minute by default, searches the last 15 minutes, and
triggers per result. Duplicate alert actions are suppressed by `workflowJobId` in
Splunk and by the DynamoDB item key in AWS.

The alert query keeps the same core logic as the Forge dashboard query and adds
`aws_region`, `forgecicd_region_alias`, and `forgecicd_vpc_alias` to the result
table so the worker can find the right tenant SSM parameters. It also extracts
`delivery_ids` from `--delivery-id` in the dispatch log and drops results where
that ID is missing. If `aws_region` is missing, the receiver tries to parse the
region from the SQS queue URL.

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
            aws_region = "us-west-2"
            vpc_alias  = "sl"
            prefix     = "cnhe-usw2-sl"
          }
        ]
      }
    ]
  }
}
```

<!-- BEGIN_TF_DOCS -->

<!-- END_TF_DOCS -->
