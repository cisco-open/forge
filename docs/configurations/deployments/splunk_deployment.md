# Splunk Integration Deployment Example

This directory provides a complete example for deploying **Forge Splunk integrations** using **Terragrunt** for layered configuration management.

---

## Module Overview

The following modules are included in this deployment:

| Module Name                        | Description                                                                 |
| ----------------------------------- | --------------------------------------------------------------------------- |
| `splunk_cloud_data_manager`         | Manages Splunk Cloud Data Manager integration for log ingestion and storage |
| `splunk_cloud_data_manager_deps`    | Handles dependencies for Splunk Cloud Data Manager                          |
| `splunk_o11y_integration`           | Integrates Splunk Observability Cloud for metrics and events                |
| `splunk_o11y_regional_integration`  | Regional Splunk Observability integration                                   |
| `splunk_otel_eks`                   | Deploys Splunk OpenTelemetry Collector on EKS                               |
| `splunk_secrets`                    | Provisions required Splunk secrets in AWS Secrets Manager                   |

---

## Prerequisites

Before deploying, ensure you have:

- An existing **VPC** and **subnets** in your AWS account.
- [Terragrunt](https://terragrunt.gruntwork.io/) and [OpenTofu](https://opentofu.org/) (or Terraform) installed.
- **AWS credentials configured** (`aws configure`) with the correct profile.
- IAM permissions to create Secrets Manager, and related resources.
- Replace **all** `<REPLACE WITH YOUR VALUE>` placeholders in these files:
  - `examples/deployments/splunk-deployment/terragrunt/_global_settings/_global.hcl`
  - `examples/deployments/splunk-deployment/terragrunt/environments/prod/_environment_wide_settings/_environment.hcl`
  - `examples/deployments/splunk-deployment/terragrunt/environments/prod/splunk_cloud_data_manager/config.hcl`
  - `examples/deployments/splunk-deployment/terragrunt/environments/prod/splunk_cloud_data_manager_deps/config.hcl`
  - `examples/deployments/splunk-deployment/terragrunt/environments/prod/splunk_o11y_integration/config.hcl`
  - `examples/deployments/splunk-deployment/terragrunt/environments/prod/splunk_secrets/config.hcl`

---

## Secrets Setup

Before deploying integrations, you must provision the required Splunk secrets in AWS Secrets Manager.  
See the [Secrets Inventory](../secrets.md) for the full list and descriptions.

**Deploy secrets first:**

```sh
cd examples/deployments/splunk-deployment/terragrunt/environments/prod/splunk_secrets/
terragrunt plan
terragrunt apply
```

After secrets are created, you may need to update their values in AWS Secrets Manager with your actual Splunk credentials and tokens.

---

## How to Deploy

To deploy all modules:

```sh
cd examples/deployments/splunk-deployment/terragrunt/environments/prod/
terragrunt run-all plan
terragrunt run-all apply
```

To deploy a specific module (example for Splunk Cloud Data Manager):

```sh
cd examples/deployments/splunk-deployment/terragrunt/environments/prod/splunk_cloud_data_manager/
terragrunt plan
terragrunt apply
```
