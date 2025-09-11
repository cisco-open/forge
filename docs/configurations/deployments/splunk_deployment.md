# Splunk Integration Deployment Example

This directory provides a complete example for deploying **Forge Splunk integrations** using **Terragrunt** for layered configuration management.

## Module Overview

The following modules are included in this deployment:

| Module Name                          | Description                                                                 |
| ------------------------------------ | --------------------------------------------------------------------------- |
| `splunk_cloud_data_manager`          | Manages Splunk Cloud Data Manager integration for log ingestion and storage |
| `splunk_cloud_data_manager_common`   | Handles dependencies for Splunk Cloud Data Manager                          |
| `splunk_o11y_aws_integration_common` | Integrates Splunk Observability Cloud for metrics and events                |
| `splunk_o11y_integration`            | Regional Splunk Observability integration                                   |
| `splunk_otel_eks`                    | Deploys Splunk OpenTelemetry Collector on EKS                               |
| `splunk_secrets`                     | Provisions required Splunk secrets in AWS Secrets Manager                   |

## Prerequisites

Before deploying:

- Ensure you have an existing **VPC** and **subnets** in your AWS account.
- Install [Terragrunt](https://terragrunt.gruntwork.io/) and [OpenTofu](https://opentofu.org/) (or Terraform).
- Configure **AWS credentials** (`aws configure`) with the correct profile.
- Ensure your IAM user/role has permissions to create EKS and related resources.

## 1. Prepare Config Files — Global and Environment

Copy these templates and place them at the correct paths:

### Templates to Copy

- `examples/templates/eks/_global_settings/_global.yaml`
- `examples/templates/eks/_environment_wide_settings/_environment.yaml`

### Destination Paths

```
examples/deployments/forge-extras/terragrunt/_global_settings/_global.yaml

examples/deployments/forge-extras/terragrunt/environments/<aws_account>/_environment_wide_settings/_environment.yaml
```

### Edit the Config Files

- **\_global.yaml**\
  Set global values such as team name, product name, AWS account prefix, GitHub organization, and contact email.\
  *(Path: `_global_settings/_global.yaml`)*

- **\_environment.yaml**\
  Define environment-wide settings like environment name, AWS region, and account ID.\
  *(Path: `environments/<aws_account>/_environment_wide_settings/_environment.yaml`)*

**Be sure to replace all placeholder values (`<...>`) with your actual environment details.**

## Secrets Setup

Before deploying integrations, you must provision the required Splunk secrets in AWS Secrets Manager.\
See the [Secrets Inventory](../secrets.md) for the full list and descriptions.

**Deploy secrets first:**

```sh
cd examples/deployments/splunk-deployment/terragrunt/environments/prod/splunk_secrets/
terragrunt plan
terragrunt apply
```

After secrets are created, you may need to update their values in AWS Secrets Manager with your actual Splunk credentials and tokens.

## How to Deploy

To deploy all modules:

```sh
cd examples/deployments/splunk-deployment/terragrunt/environments/prod/
terragrunt plan --all
terragrunt apply --all
```

To deploy a specific module (example for Splunk Cloud Data Manager):

```sh
cd examples/deployments/splunk-deployment/terragrunt/environments/prod/splunk_cloud_data_manager/
terragrunt plan
terragrunt apply
```
