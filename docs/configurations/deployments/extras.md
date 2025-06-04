# 🛠️ Forge Extras Deployment Example

This directory contains example configurations for deploying **Forge infrastructure extras** using **Terragrunt** for layered configuration management.

---

## 📦 Module Overview

The following modules are included in this deployment:

| Module Name         | Description                                                      |
|---------------------|------------------------------------------------------------------|
| `cloud_custodian`   | Applies Cloud Custodian policies for AWS resource governance     |
| `cloud_formation`   | Grants CloudFormation permissions for integrations and automation|
| `ecr`               | Provisions ECR repositories for storing runner/container images  |
| `forge_subscription` | Manages Forge subscription resources, allowing Forge runners to assume roles in tenant accounts and pull ECR images across accounts. Supports both self-subscription and tenant onboarding scenarios. |
| `storage`           | Provisions S3 buckets for integrations and data storage          |

---

## 🛠️ Prerequisites

Before deploying, ensure you have:

- An existing **VPC** and **subnets** in your AWS account.
- [Terragrunt](https://terragrunt.gruntwork.io/) and [OpenTofu](https://opentofu.org/) (or Terraform) installed.
- **AWS credentials configured** (`aws configure`) with the correct profile.
- IAM permissions to create and manage the required AWS resources.
- All `<REPLACE WITH YOUR VALUE>` placeholders updated in:
  - `terragrunt/_global_settings/_global.hcl`
  - `terragrunt/environments/prod/_environment_wide_settings/_environment.hcl`
  - Any module-specific config files (e.g., `cloud_custodian.hcl`, `cloud_formation.hcl`, `ecr.hcl`, `forge_subscription.hcl`, `storage.hcl`)

---

## 🚀 How to Deploy

To deploy all modules:

```sh
cd terragrunt/environments/prod/
terragrunt run-all plan
terragrunt run-all apply
```

To deploy a specific module (example for Cloud Custodian):

```sh
cd terragrunt/environments/prod/cloud_custodian/
terragrunt plan
terragrunt apply
```
