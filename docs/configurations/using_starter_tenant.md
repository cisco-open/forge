# Forge Multi-Tenant Deployment Example

This folder contains a complete multi-tenant **Forge** deployment using **Terragrunt** for layered configuration management.


## Module Overview

The following module is deployed as part of this configuration:

| Module          | Description                                                                                                                 |
| --------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `forge_runners` | Provisions ephemeral GitHub Actions runners (EC2 and EKS) with tenant isolation, autoscaling, and full lifecycle automation |


## Prerequisites

Before deploying Forge:

* You **must have a VPC, subnets, and an EKS cluster** available.

* You can either:

  * Use your existing AWS infrastructure, **or**
  * Deploy a compatible cluster using Forge’s own [EKS Terraform module](https://github.com/cisco-open/forge/tree/main/modules/infra/eks) or create your own standard EKS cluster.

* Replace **all** `<REPLACE WITH YOUR VALUE>` placeholders in these files:

  * `examples/deployments/starter-tenant/terragrunt/environments/prod/regions/eu-west-1/vpcs/sl/_vpc_wide_settings/_vpc.hcl`
  * `examples/deployments/starter-tenant/terragrunt/_global_settings/_global.hcl`
  * `examples/deployments/starter-tenant/terragrunt/environments/prod/_environment_wide_settings/_environment.hcl`


## Adding a New Tenant

To provision a new tenant, follow the step-by-step guide:

[docs/configurations/new_tenant.md](../../docs/configurations/new_tenant.md)


## How to Deploy

From the environment root directory, deploy all tenants at once:

```sh
cd examples/deployments/starter-tenant/terragrunt/environments/prod/
terragrunt run-all plan
terragrunt run-all apply
```

Or deploy a single tenant individually by navigating to its folder:

```sh
cd examples/deployments/starter-tenant/terragrunt/environments/prod/regions/<region>/vpcs/<vpc_alias>/tenants/<tenant_name>/
terragrunt plan
terragrunt apply
```

Choose the approach that fits your workflow.
