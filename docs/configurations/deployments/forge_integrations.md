# Forge Integration Deployment Example

This directory provides a working example of deploying **Forge integrations** using **Terragrunt** for layered configuration management.

---

## Module Overview

| Module                      | Description                                                                   |
| --------------------------- | ----------------------------------------------------------------------------- |
| `splunk_cloud_data_manager` | Configures Splunk Cloud Data Manager for ingesting logs and events            |
| `splunk_cloud_conf_shared`  | Applies shared Splunk Observability configurations (dashboards, alerts, etc.) |

---

## Prerequisites

Before deploying:

- Ensure a **VPC**, **subnets**, and an **EKS cluster** are available.
- Install [Terragrunt](https://terragrunt.gruntwork.io/) and [OpenTofu](https://opentofu.org/) (or Terraform).
- Configure **AWS credentials** (`aws configure`) with the correct profile.
- You can use your existing infrastructure or deploy a new cluster using the [Forge EKS module](https://github.com/cisco-open/forge/tree/main/modules/infra/eks)(Check the [EKS Example](./forge_eks.md)) or any standard setup.
- Replace **all** `<REPLACE WITH YOUR VALUE>` placeholders in these files:
  - `examples/deployments/forge-integrations/terragrunt/_global_settings/_global.hcl`
  - `examples/deployments/forge-integrations/terragrunt/environments/prod/_environment_wide_settings/_environment.hcl`
- The `splunk_cloud_forgecicd` module depends on tenant definitions.
  - To define tenants, follow: [New Tenant Guide](./new_tenant.md)

---

## Deployment

To deploy all modules:

```sh
cd examples/deployments/forge-integrations/terragrunt/environments/prod/
terragrunt plan --all
terragrunt apply --all
```

To deploy a specific module:

```sh
cd examples/deployments/forge-integrations/terragrunt/environments/prod/splunk_cloud_conf/
terragrunt plan
terragrunt apply
```

```sh
cd examples/deployments/forge-integrations/terragrunt/environments/prod/splunk_cloud_forgecicd/
terragrunt plan
terragrunt apply
```
