# Forge Multi-Tenant Deployment Example

This folder contains a complete multi-tenant **Forge** deployment using **Terragrunt** for layered configuration management.


## Module Overview

The following module is deployed as part of this configuration:

| Module          | Description                                                                                                                 |
| --------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `forge_runners` | Provisions ephemeral GitHub Actions runners (EC2 and EKS) with tenant isolation, autoscaling, and full lifecycle automation |


## Prerequisites

Before deploying Forge:

- Ensure a **VPC**, **subnets**, and an **EKS cluster** are available.
- Install [Terragrunt](https://terragrunt.gruntwork.io/) and [OpenTofu](https://opentofu.org/) (or Terraform).
- Configure **AWS credentials** (`aws configure`) with the correct profile.
- You can use your existing infrastructure or deploy a new cluster using the [Forge EKS module](https://github.com/cisco-open/forge/tree/main/modules/infra/eks)(Check the [EKS Example](./forge_eks.md)) or any standard setup.
- Replace **all** `<REPLACE WITH YOUR VALUE>` placeholders in these files:
  - `examples/deployments/forge-tenant/terragrunt/environments/prod/regions/eu-west-1/vpcs/sl/_vpc_wide_settings/_vpc.hcl`
  - `examples/deployments/forge-tenant/terragrunt/_global_settings/_global.hcl`
  - `examples/deployments/forge-tenant/terragrunt/environments/prod/_environment_wide_settings/_environment.hcl`


## Adding a New Tenant

To provision a new tenant, follow the step-by-step guide:

[Deploy a New Tenant ](./new_tenant.md)


## How to Deploy

From the environment root directory, deploy all tenants at once:

```sh
cd examples/deployments/forge-tenant/terragrunt/environments/prod/
terragrunt run-all plan
terragrunt run-all apply
```

Or deploy a single tenant individually by navigating to its folder:

```sh
cd examples/deployments/forge-tenant/terragrunt/environments/prod/regions/<region>/vpcs/<vpc_alias>/tenants/<tenant_name>/
terragrunt plan
terragrunt apply
```

Choose the approach that fits your workflow.
