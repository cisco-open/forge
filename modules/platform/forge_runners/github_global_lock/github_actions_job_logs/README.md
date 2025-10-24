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
