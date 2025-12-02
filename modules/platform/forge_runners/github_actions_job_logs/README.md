# GitHub Actions Job Log Archiver Module

Archives completed GitHub Actions workflow job logs into per-tenant S3 buckets for audit, troubleshooting, and retention requirements.

## Features
- Per-tenant buckets (auto-created or externally provided)
- Two processing modes:
  - Direct (legacy): EventBridge -> downloader Lambda -> S3
  - Queue pipeline (default): EventBridge -> dispatcher Lambda -> SQS -> downloader Lambda (better isolation, retry & backpressure)
- GitHub App authentication (JWT + installation token) to fetch job logs
- EventBridge rule listening for `workflow_job.completed` events (via existing webhook relay -> EventBridge integration)
- Optional KMS encryption
- Shared read/list access for platform/observability roles
- Versioning & basic lifecycle management

## How It Works
### Queue Pipeline (default)
1. GitHub webhook (workflow_job events) reaches your existing relay (not part of this module) which forwards events onto EventBridge as detail-type `GitHub Webhook`.
2. EventBridge rule filters for `workflow_job` with `action=completed`.
3. Dispatcher Lambda validates mapping & completion status, then enqueues a concise message to SQS.
4. Downloader Lambda (SQS trigger) consumes batches, performs GitHub API log download, and writes to S3.
5. Object stored at: `s3://<bucket>/<workflow_name>/<run_attempt>/<job_id>.zip`.

### Direct Mode (fallback)
Set `enable_queue_pipeline = false` to revert to the original single-Lambda flow (less durable, fewer moving parts for very low volume environments).

## Inputs
See `variables.tf` for full list. Key inputs:
- `repo_tenant_map` (map) : Maps `org/repo` -> tenant id.
- `github_app_id`, `github_app_private_key_secret_arn` : GitHub App credentials.
- `github_app_installation_id` : Optional fixed installation id (skip lookup per repo).
- `kms_key_arn` : Optional SSE-KMS key for encryption.
- `shared_role_arns` : Optional map of role ARNs granted read-list across all buckets.
- `enable_queue_pipeline` : Toggle queue pipeline (default true).
- `sqs_visibility_timeout_seconds`, `sqs_max_receive_count` : Queue configuration.
- `downloader_batch_size`, `downloader_max_concurrency` : SQS batch processing tuning.

## Outputs
- `bucket_names` : tenant -> bucket mapping.
- `lambda_function_name` / `lambda_function_arn`.

## Bucket Naming
Uses `bucket_name_format` replacing `{{tenant}}` with tenant id. Provide pre-created buckets by setting `create_buckets = false` and ensuring the names exist.

## Example (Queue Pipeline)
```hcl
module "gha_job_log_archiver" {
  source = "../modules/integrations/github_actions_job_log_archiver"

  repo_tenant_map = {
    "myorg/app-service" = "tenant-a"
    "myorg/api-gateway" = "tenant-b"
  }

  github_app_id                      = var.github_app_id
  github_app_private_key_secret_arn  = var.github_app_private_key_secret_arn
  github_app_installation_id         = var.github_app_installation_id # optional
  kms_key_arn                        = var.logs_kms_key_arn           # optional
  shared_role_arns = {
    observability = aws_iam_role.observability.arn
  }
  tags = var.tags
}
```

## Example (Direct Mode)
```hcl
module "gha_job_log_archiver" {
  source = "../modules/integrations/github_actions_job_log_archiver"
  enable_queue_pipeline = false
  repo_tenant_map = { "myorg/app-service" = "tenant-a" }
  github_app_id                     = var.github_app_id
  github_app_private_key_secret_arn = var.github_app_private_key_secret_arn
}
```

## Required GitHub App Permissions
- Actions: Read
- Metadata: Read

## IAM / Security Notes
- Ensure the provided KMS key allows the Lambda role to `Encrypt/Decrypt/GenerateDataKey`.
- Bucket policies (shared access) are not yet explicitly created; consider future enhancement if central read roles need cross-account access.

## Future Enhancements
- Add optional CloudWatch metric/log filters for download errors.
- Retry & backoff for GitHub API secondary rate limits / 403 abuse detection.
- Support artifact / log size tagging in object metadata.
- Add SQS FIFO option for strict ordering per repository.

## Event Shape Assumption
Expecting EventBridge detail of form (subset):
```json
{
  "detail": {
    "repository": { "full_name": "org/repo" },
    "action": "completed",
    "workflow_job": {
      "id": 123456789,
      "run_id": 987654321,
      "run_attempt": 1,
      "name": "build",
      "workflow_name": "CI",
      "status": "completed",
      "conclusion": "success"
    }
  }
}
```

## Local Development
Package the Lambda:
```bash
(cd modules/integrations/github_actions_job_log_archiver/lambda && zip job_log_archiver.zip job_log_archiver.py)
```
Then re-run Terraform apply so the updated `source_code_hash` triggers deployment.

## License
See parent repository license.

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
| <a name="module_job_log_archiver"></a> [job\_log\_archiver](#module\_job\_log\_archiver) | terraform-aws-modules/lambda/aws | 8.1.2 |
| <a name="module_job_log_dispatcher"></a> [job\_log\_dispatcher](#module\_job\_log\_dispatcher) | terraform-aws-modules/lambda/aws | 8.1.2 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.job_log_dispatcher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.job_log_dispatcher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.job_log_archiver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.job_log_dispatcher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_policy.internal_s3_reader_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.internal_s3_reader](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.attach_internal_s3_reader](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.gh_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.gh_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_lambda_event_source_mapping.job_log_archiver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_permission.job_log_dispatcher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.scale_runners_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_s3_bucket.gh_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.gh_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.gh_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.gh_logs_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.gh_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.gh_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.gh_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_sqs_queue.jobs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.jobs_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.internal_s3_reader_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.internal_s3_reader_policy_doc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.job_log_archiver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.job_log_dispatcher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_secretsmanager_secret.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret_version.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_event_bus_name"></a> [event\_bus\_name](#input\_event\_bus\_name) | Name of the EventBridge event bus to listen for workflow job events. | `string` | n/a | yes |
| <a name="input_ghes_url"></a> [ghes\_url](#input\_ghes\_url) | GitHub Enterprise Server URL. | `string` | `""` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR) | `string` | `"INFO"` | no |
| <a name="input_logging_retention_in_days"></a> [logging\_retention\_in\_days](#input\_logging\_retention\_in\_days) | Retention in days for CloudWatch Log Group for the Lambdas. | `number` | `30` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix for all resources | `string` | n/a | yes |
| <a name="input_secrets_prefix"></a> [secrets\_prefix](#input\_secrets\_prefix) | Prefix for all secrets | `string` | n/a | yes |
| <a name="input_shared_role_arns"></a> [shared\_role\_arns](#input\_shared\_role\_arns) | Optional list of consumer identifier to IAM Role ARN granted read/list on tenant's github job logs. | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to created resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_internal_s3_reader_role_arn"></a> [internal\_s3\_reader\_role\_arn](#output\_internal\_s3\_reader\_role\_arn) | The ARN of the IAM role used for reading from the S3 bucket. |
| <a name="output_s3_bucket_arn"></a> [s3\_bucket\_arn](#output\_s3\_bucket\_arn) | The ARN of the S3 bucket where GitHub Actions job logs are stored. |
<!-- END_TF_DOCS -->
