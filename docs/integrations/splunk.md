# Splunk

Splunk modules are optional. Deploy them only when Splunk Cloud or Splunk
Observability is part of your operating model.

For day-2 operations, use the
[Splunk Dashboard Runbook](../operations/splunk-dashboard-runbook.md) and
[Splunk Dashboard Panel Reference](../operations/splunk-dashboard-panel-reference.md).

ForgeMT baseline platform logs go to CloudWatch. Splunk adds optional
dashboards, saved searches, redelivery logic, billing ingestion, S3 log
ingestion, and metrics views. AWS billing and S3 log ingestion are
integration-specific paths: they may send data to Splunk directly or through
Kinesis when those modules are deployed.

## Module Families

| Module family                          | Purpose                                                                 |
| -------------------------------------- | ----------------------------------------------------------------------- |
| `splunk_secrets`                       | Creates or manages Splunk secrets.                                      |
| `splunk_cloud_*`                       | Splunk Cloud config, data manager, HEC, dashboards, and saved searches. |
| `splunk_o11y_*`                        | Splunk Observability AWS and EKS telemetry.                             |
| `splunk_opencost_eks`                  | OpenCost data for EKS.                                                  |
| `splunk_aws_billing`                   | Billing telemetry.                                                      |
| `splunk_stuck_workflow_job_dispatcher` | Dispatches stuck workflow job handling from Splunk search results.      |

## Dashboard Surfaces

| Surface                         | Use it for                                                                                                            |
| ------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Splunk Cloud dashboards         | Logs, field extraction, workflow jobs, runner lifecycle, trust failures, stuck-job redelivery, and ingestion quality. |
| Splunk Observability dashboards | Metrics, resource pressure, cost, runner capacity, Lambda, SQS, DynamoDB, EBS, and OpenCost.                          |

Use Splunk Cloud logs to explain what happened. Use Splunk Observability
metrics to explain whether resource pressure contributed to it.

## Deploy Path

Use:

```text
examples/deployments/integrations
examples/templates/integrations
modules/integrations/splunk_*
```

Deploy root:

```text
examples/deployments/integrations/terragrunt
```

## Deployment Order

| Step | Directory                                                         | Why it comes here                                     |
| ---- | ----------------------------------------------------------------- | ----------------------------------------------------- |
| 1    | `environments/prod/splunk_secrets`                                | Creates or references Splunk secrets.                 |
| 2    | `environments/prod/splunk_o11y_aws_integration_common`            | Common AWS/Splunk Observability prerequisites.        |
| 3    | `environments/prod/splunk_cloud_data_manager_common`              | Common Splunk Cloud Data Manager prerequisites.       |
| 4    | `environments/prod/regions/eu-west-1/splunk_o11y_aws_integration` | Regional AWS Observability integration.               |
| 5    | `environments/prod/regions/eu-west-1/splunk_otel_eks`             | EKS OpenTelemetry collector, only if using EKS.       |
| 6    | `environments/prod/regions/eu-west-1/splunk_opencost_eks`         | EKS cost telemetry, only if using EKS/OpenCost.       |
| 7    | `environments/prod/splunk_cloud_data_manager`                     | Splunk Cloud log ingestion configuration.             |
| 8    | `environments/prod/splunk_cloud_conf_shared`                      | Shared Splunk Cloud saved searches and configuration. |
| 9    | `environments/prod/splunk_o11y_conf_shared`                       | Shared Splunk Observability dashboards and detectors. |
| 10   | `environments/prod/splunk_aws_billing`                            | Billing telemetry, only if you publish billing data.  |
| 11   | `environments/prod/splunk_cloud_s3_runner_logs`                   | Runner log ingestion from S3, only if enabled.        |
| 12   | `environments/prod/splunk_stuck_workflow_job_dispatcher`          | Alert and redelivery workflow for stuck GitHub jobs.  |

You do not have to deploy every Splunk module. Pick the rows that match your
Splunk contract.

## What You Edit

| File                                                            | Change                                                              |
| --------------------------------------------------------------- | ------------------------------------------------------------------- |
| `_global_settings/_global.yml`                                  | Team, product, project, GitHub org, and owner defaults.             |
| `environments/prod/_environment_wide_settings/_environment.yml` | AWS account, default region, AWS profile, and remote state.         |
| `environments/prod/splunk_secrets/config.yml`                   | Secret names and placeholder values managed by Terraform.           |
| `environments/prod/splunk_*/*config.yml`                        | Splunk realm, URLs, indexes, tokens, roles, buckets, and schedules. |
| `environments/prod/regions/eu-west-1/splunk_*/*config.yml`      | Regional EKS, OTel, OpenCost, or AWS integration values.            |
| `release_versions.yml`                                          | Splunk module sources, refs, and `module_path` values.              |

The full secret list is in [Splunk Secrets](splunk-secrets.md).

## Apply Secrets First

```bash
cd examples/deployments/integrations/terragrunt/environments/prod/splunk_secrets
terragrunt plan
terragrunt apply
```

After the secret resources exist, update the real values in AWS Secrets Manager
using your approved process. Change the example names if your company uses a
different naming standard.

## Apply One Splunk Module

Common Observability setup:

```bash
cd examples/deployments/integrations/terragrunt/environments/prod/splunk_o11y_aws_integration_common
terragrunt plan
terragrunt apply
```

Regional Observability setup:

```bash
cd examples/deployments/integrations/terragrunt/environments/prod/regions/eu-west-1/splunk_o11y_aws_integration
terragrunt plan
terragrunt apply
```

EKS OpenTelemetry collector:

```bash
cd examples/deployments/integrations/terragrunt/environments/prod/regions/eu-west-1/splunk_otel_eks
terragrunt plan
terragrunt apply
```

Plan the whole integration environment only after single-module plans are clean:

```bash
cd examples/deployments/integrations/terragrunt/environments/prod
terragrunt plan --all
```

## Required Helpers Or External Equivalents

Some Splunk modules need resources that can come from Forge helpers or from your
existing platform:

| Need                                          | Forge helper option                   | External equivalent                                        |
| --------------------------------------------- | ------------------------------------- | ---------------------------------------------------------- |
| S3 buckets for logs, billing, or data manager | `modules/helpers/storage`             | Pre-created buckets with matching policies.                |
| CloudFormation admin/execution roles          | `modules/helpers/cloud_formation`     | Existing roles with the required Splunk stack permissions. |
| Secret storage                                | `modules/integrations/splunk_secrets` | Existing AWS Secrets Manager entries.                      |
| EKS cluster for OTel/OpenCost                 | `modules/infra/eks`                   | Existing EKS cluster and Kubernetes access.                |

If you use external equivalents, wire those values into the corresponding
`config.yml` and skip the helper module.

## Skip Path

If you do not use Splunk:

- delete Splunk folders from your integrations repo
- do not create Splunk secrets
- do not block Forge platform deployment on dashboards or saved searches
- use your existing log/metric pipeline for runner observability
