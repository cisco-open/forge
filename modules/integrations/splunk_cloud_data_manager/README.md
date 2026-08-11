# Splunk Cloud Data Manager

This module configures Splunk Data Manager integrations for AWS log and metadata ingestion.

## Why This Module Exists

Forge sends EC2, Lambda, EKS, CloudWatch, and security metadata through supported Splunk Cloud ingestion paths. Managing Data Manager as code keeps observability reproducible instead of click-driven.

## What It Manages

- CloudFormation stacks for CloudWatch, custom CloudWatch, S3/SQS logs, and security metadata integrations.
- Generated Splunk data input modules for each integration payload.
- A metadata Lambda trigger for EC2 tag enrichment.
- One regional reconciler Lambda that applies Forge tags to the default log groups of Splunk-managed Lambdas and deletes those groups after the owning Data Manager functions are removed.
- Outputs containing the resulting Splunk input JSON.

## Operational Notes

- This module expects valid Splunk Cloud credentials and Data Manager configuration.
- `python3.12` must be available on the host running OpenTofu because Data Manager lifecycle operations execute locally.
- CloudFormation stack failures usually point to AWS-side permissions or region support.
- Custom log group selection determines which Forge logs arrive in Splunk Cloud.
- Configure each S3 input's IAM roles region independently from the regions containing its queues and buckets.
- Use S3 bucket-name patterns such as `forge-runner-logs-*`, or `*` when no narrower prefix is available.
- Give S3 log inputs dedicated SQS queues; competing consumers can remove notifications before Data Manager reads them.
- Group S3 inputs under the five dataset keys in `s3_logs_config`. Each enabled list item creates an independent Data Manager input and CloudFormation stack, and input names must be unique across all five lists.
- `source_type` belongs only to custom S3 log items. Predefined dataset requests omit Splunk's `sourceType` field.
- S3 input names are also stable Terraform instance keys. Reordering list items is safe, while renaming an input replaces that input's managed UUID and stack.
- To rename an input that will reuse the same queue, first disable and apply the old item, then rename, re-enable, and apply it. This prevents old and new consumers from overlapping.
- Each item's `enabled`, `name`, and `iam_region` values must be known during planning because they determine instance membership, identity, and the stack region.
- The OpenTofu caller needs `lambda:InvokeFunction` for each regional reconciler. The helper execution role has only the regional CloudFormation and CloudWatch Logs permissions required by its handler.
- On create and update, the helper walks the exact regional `SplunkDM*` stack IDs (including nested stacks), derives `/aws/lambda/<physical-function-name>`, creates that exact group if it is late, and upserts the configured tags without removing unrelated keys.
- A regional EventBridge rule receives Lambda `DeleteFunction20150331` management events from CloudTrail. For a `SplunkDM*` physical name in the same account and region, the helper idempotently deletes only `/aws/lambda/<physical-function-name>`.
- Deletion automation requires an enabled CloudTrail trail that records Lambda management events, and delivery to EventBridge is best effort. Existing legacy groups whose function was deleted before this helper was deployed are intentionally left untouched.
- Helper resources use the AWS provider v6 per-resource `region` argument so each active Data Manager region receives an isolated Lambda and deletion rule.

| S3 log type | Configuration key | `source_type` |
| --- | --- | --- |
| Custom S3 logs | `s3-custom-logs` | Required |
| AWS CloudTrail | `ct-logs` | Omit |
| Amazon S3 access logs | `s3-access-logs` | Omit |
| Elastic Load Balancing access logs | `elb-access-logs` | Omit |
| Amazon CloudFront access logs | `cf-access-logs` | Omit |

<!-- BEGIN_TF_DOCS -->

<!-- END_TF_DOCS -->
