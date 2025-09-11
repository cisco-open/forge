# Forge EKS Deployment Example

This directory provides a working example of deploying **Forge EKS** using **Terragrunt** for layered configuration management.

## Module Overview

| Module | Description                                                                        |
| ------ | ---------------------------------------------------------------------------------- |
| `eks`  | Configures an EKS cluster with Calico and Karpenter for networking and autoscaling |

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
examples/deployments/forge-eks/terragrunt/_global_settings/_global.yaml

examples/deployments/forge-eks/terragrunt/environments/<aws_account>/_environment_wide_settings/_environment.yaml
```

### Edit the Config Files

- **\_global.yaml**\
  Set global values such as team name, product name, AWS account prefix, GitHub organization, and contact email.\
  *(Path: `_global_settings/_global.yaml`)*

- **\_environment.yaml**\
  Define environment-wide settings like environment name, AWS region, and account ID.\
  *(Path: `environments/<aws_account>/_environment_wide_settings/_environment.yaml`)*

**Be sure to replace all placeholder values (`<...>`) with your actual environment details.**

## 2. Prepare EKS Config File

Copy the EKS config template and place it at the correct path:

### Template to Copy

- `examples/templates/eks/eks/config.yaml`

### Destination Path

```
examples/deployments/forge-eks/terragrunt/environments/<aws_account>/regions/<aws_region>/eks/config.yaml
```

**Be sure to replace all placeholder values (`<...>`) with your actual environment details.**

## Deployment

To deploy all modules:

```sh
cd examples/deployments/forge-eks/terragrunt/environments/prod/
terragrunt plan --all
terragrunt apply --all
```

To deploy only the EKS module:

```sh
cd examples/deployments/forge-eks/terragrunt/environments/prod/regions/<aws_region>/eks/
terragrunt plan
terragrunt apply
```

> For more advanced scenarios or troubleshooting, see the [full documentation](../index.md).
