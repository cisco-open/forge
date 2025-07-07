# Forge Multi-Tenant Deployment Example

This folder contains a complete multi-tenant **Forge** deployment using **Terragrunt** for layered configuration management.

## Module Overview

| Module          | Description                                                                                                                 |
| --------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `forge_runners` | Provisions ephemeral GitHub Actions runners (EC2 and EKS) with tenant isolation, autoscaling, and full lifecycle automation |

## Prerequisites

Before deploying Forge:

- Ensure a **VPC**, **subnets**, and an **EKS cluster** are available.
- Install [Terragrunt](https://terragrunt.gruntwork.io/) and [OpenTofu](https://opentofu.org/) (or Terraform).
- Configure **AWS credentials** (`aws configure`) with the correct profile.
- You can use your existing infrastructure or deploy a new cluster using the [Forge EKS module](https://github.com/cisco-open/forge/tree/main/modules/infra/eks) (see the [EKS Example](./forge_eks.md)) or any standard setup.


## 1. Prepare Config Files — Global, Environment, and VPC

Copy these templates and place them at the correct paths:

### Templates to Copy

- `examples/templates/tenant/_global_settings/_global.yaml`
- `examples/templates/tenant/_environment_wide_settings/_environment.yaml`
- `examples/templates/tenant/_vpc_wide_settings/_vpc.yaml`

### Destination Paths

```
examples/deployments/forge-tenant/terragrunt/_global_settings/_global.yaml

examples/deployments/forge-tenant/terragrunt/environments/<aws_account>/_environment_wide_settings/_environment.yaml

examples/deployments/forge-tenant/terragrunt/environments/<aws_account>/regions/<aws_region>/vpcs/<vpc_alias>/_vpc_wide_settings/_vpc.yaml
```

### Edit the Config Files

Before editing your tenant's `config.yaml`, review and update these supporting configuration files:

- **_global.yaml**  
  Set global values such as team name, product name, AWS account prefix, GitHub organization, and contact email.  
  *(Path: `_global_settings/_global.yaml`)*

- **_environment.yaml**  
  Define environment-wide settings like environment name, AWS region, and account ID.  
  *(Path: `environments/<aws_account>/_environment_wide_settings/_environment.yaml`)*

- **_vpc.yaml**  
  Specify VPC-wide settings including VPC alias, VPC ID, subnet IDs, and cluster name.  
  *(Path: `environments/<aws_account>/regions/<aws_region>/vpcs/<vpc_alias>/_vpc_wide_settings/_vpc.yaml`)*

These files provide the foundational settings used by your tenant and runner modules.  
**Be sure to replace all placeholder values (`<...>`) with your actual environment details.**


## 2. Adding a New Tenant

To provision a new tenant, follow the step-by-step guide:  
👉 [Deploy a New Tenant](./new_tenant.md)

## 3. How to Deploy

From the environment root directory, deploy all tenants at once:

```sh
cd examples/deployments/forge-tenant/terragrunt/environments/prod/
terragrunt plan --all
terragrunt apply --all
```

Or deploy a single tenant individually by navigating to its folder:

```sh
cd examples/deployments/forge-tenant/terragrunt/environments/prod/regions/<region>/vpcs/<vpc_alias>/tenants/<tenant_name>/
terragrunt plan
terragrunt apply
```

Choose the approach that fits your workflow.

---

> For more advanced scenarios or troubleshooting, see the [full documentation](../index.md).
