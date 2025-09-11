# Dependency Table

> **Note:**\
> Dependencies on `modules/infra/secrets` and `modules/infra/storage` are **optional** — use them only if managing secrets or storage via Terraform.\
> If secrets or buckets are created manually or managed elsewhere, these modules are not required.

______________________________________________________________________

## Infrastructure Modules

| **Module**                           | **Dependencies**                                                                          | **Description**                                                                                              |
| ------------------------------------ | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `modules/infra/storage`              | None                                                                                      | Provides S3 buckets for temporary uploads, CloudFormation templates, and other ephemeral assets.             |
| `modules/infra/opt_in_regions`       | None                                                                                      | Enables specific AWS regions for deployment.                                                                 |
| `modules/infra/service_linked_roles` | None                                                                                      | Enables EC2 Spot and other AWS service-linked roles.                                                         |
| `modules/infra/eks`                  | **Optional:** `infra/secrets` <br> **Required:** `opt_in_regions`, `service_linked_roles` | Deploys EKS cluster with Calico and Karpenter. Integrates with Splunk.                                       |
| `modules/infra/cloud_formation`      | None                                                                                      | Manages CloudFormation stacks used by integrations.                                                          |
| `modules/infra/ami_policy`           | None                                                                                      | Manages lifecycle policies for Forge AMIs.                                                                   |
| `modules/infra/ami_sharing`          | None                                                                                      | Shares base AMIs with tenant accounts for reuse.                                                             |
| `modules/infra/billing`              | None                                                                                      | Creates SNS topic for AWS Budgets alerts with strict publish policy.                                         |
| `modules/infra/budgets`              | **Required:** `infra/billing`                                                             | Adds AWS Budgets with per-service thresholds and alerts.                                                     |
| `modules/infra/forge_subscription`   | None                                                                                      | Enables tenants to self-register, build AMIs, pull ECR images, and assume roles. Useful for Forge-as-tenant. |

______________________________________________________________________

## Platform Modules

| **Module**                        | **Dependencies**                                                              | **Description**                                                                        |
| --------------------------------- | ----------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `modules/platform/forge_runners`  | **Required:** `infra/billing` <br> **Optional:** `infra/service_linked_roles` | Orchestrates EC2/EKS runners and tenant modules. Entry point for provisioning runners. |
| `modules/platform/ec2_deployment` | Internal (uses `terraform-aws-github-runner`)                                 | Deploys EC2-based ephemeral GitHub Actions runners.                                    |
| `modules/platform/arc_deployment` | Internal (wraps `core/arc`)                                                   | Deploys EKS-based GitHub runners via ARC.                                              |

______________________________________________________________________

## Core ARC Module

| **Module**         | **Dependencies**         | **Description**                                                                                           |
| ------------------ | ------------------------ | --------------------------------------------------------------------------------------------------------- |
| `modules/core/arc` | Used by `arc_deployment` | Version-agnostic Helm wrapper for ARC. Includes logging, pre-hooks, and tenant-aware configuration logic. |

______________________________________________________________________

## Integration Modules: Splunk

| **Module**                                                | **Dependencies**                                                                                                                                                         | **Description**                                                     |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------- |
| `modules/integrations/splunk_secrets`                     | None                                                                                                                                                                     | Manages Splunk-specific secrets like ingest tokens and credentials. |
| `modules/integrations/splunk_eks_otel`                    | **Required:** `infra/eks` <br> **Secrets:** `/cicd/common/splunk_o11y_ingest_token_eks`, `/cicd/common/splunk_cloud_hec_token_eks`                                       | Installs and configures Splunk OpenTelemetry agent in EKS.          |
| `modules/integrations/splunk_o11y_aws_integration`        | **Required:** `splunk_o11y_aws_integration_common`, `infra/cloud_formation` <br> **Optional:** `splunk_secrets` <br> **Secrets:** username/password, ingest token        | Connects AWS account to Splunk Observability.                       |
| `modules/integrations/splunk_o11y_aws_integration_common` | **Required:** `infra/cloud_formation` <br> **Optional:** `splunk_secrets` <br> **Secrets:** username/password                                                            | Common module used across Splunk Observability integrations.        |
| `modules/integrations/splunk_cloud_data_manager`          | **Required:** `splunk_cloud_data_manager_common`, `infra/cloud_formation` <br> **Optional:** `splunk_secrets`, `infra/storage` <br> **Secrets:** Cloud username/password | Provisions and manages Splunk Cloud data ingestion.                 |
| `modules/integrations/splunk_cloud_data_manager_common`   | **Required:** `infra/cloud_formation` <br> **Optional:** `splunk_secrets`, `infra/storage` <br> **Secrets:** Cloud username/password                                     | Common base for data manager integrations.                          |
| `modules/integrations/splunk_cloud_conf_shared`           | **Optional:** `splunk_secrets`, `splunk_cloud_data_manager` <br> **Secrets:** `/cicd/common/splunk_cloud_api_token`                                                      | Creates shared Splunk Cloud dashboards and global configuration.    |

______________________________________________________________________

## Integration Modules: Access & Auditing

| **Module**                      | **Dependencies**                                   | **Description**                                                                        |
| ------------------------------- | -------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `modules/integrations/teleport` | **Optional:** `modules/infra/eks`, `infra/secrets` | Deploys Teleport agents for secure access and session auditing in Kubernetes clusters. |
