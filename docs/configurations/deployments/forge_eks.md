# Forge EKS Deployment Example

This directory provides a working example of deploying **Forge EKS** using **Terragrunt** for layered configuration management.

---

## Module Overview

| Module | Description                                                        |
|--------|--------------------------------------------------------------------|
| `eks`  | Configures an EKS cluster with Calico and Karpenter for networking and autoscaling |

---

## Prerequisites

Before deploying:

- You must have an existing **VPC** and **subnets** in your AWS account.
- Install [Terragrunt](https://terragrunt.gruntwork.io/) and [OpenTofu](https://opentofu.org/) (or Terraform).
- Configure **AWS credentials** (`aws configure`) with the correct profile.
- Ensure your IAM user/role has permissions to create EKS and related resources.
- Replace **all** `<REPLACE WITH YOUR VALUE>` placeholders in these files:
  - `examples/deployments/forge-eks/terragrunt/_global_settings/_global.hcl`
  - `examples/deployments/forge-eks/terragrunt/environments/prod/_environment_wide_settings/_environment.hcl`
  - `examples/deployments/forge-eks/terragrunt/environments/prod/regions/eu-west-1/eks/config.hcl`

---

## Deployment

To deploy all modules:

```sh
cd examples/deployments/forge-eks/terragrunt/environments/prod/
terragrunt run-all plan
terragrunt run-all apply
```

To deploy only the EKS module:

```sh
cd examples/deployments/forge-eks/terragrunt/environments/prod/regions/eu-west-1/eks/
terragrunt plan
terragrunt apply
```
