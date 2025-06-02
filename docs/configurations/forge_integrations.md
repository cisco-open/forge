# Forge Integration Deployment Example

This directory provides a working example of deploying **Forge integrations** using **Terragrunt** for layered configuration management.

---

## Module Overview

This example deploys the following modules:

| Module                      | Description                                                                   |
| --------------------------- | ----------------------------------------------------------------------------- |
| `splunk_cloud_data_manager` | Configures Splunk Cloud Data Manager for ingesting logs and events            |
| `splunk_cloud_conf_shared`  | Applies shared Splunk Observability configurations (dashboards, alerts, etc.) |

---

## Prerequisites

Before deploying:

* Ensure a **VPC**, **subnets**, and an **EKS cluster** are available.

  * You can use your existing infrastructure or deploy a new cluster using the [Forge EKS module](https://github.com/cisco-open/forge/tree/main/modules/infra/eks) or any standard setup.

* Update all required values in these files by replacing `<REPLACE WITH YOUR VALUE>` placeholders:

  * `terragrunt/_global_settings/_global.hcl`
  * `terragrunt/environments/prod/_environment_wide_settings/_environment.hcl`
  * `terragrunt/environments/prod/regions/eu-west-1/vpcs/sl/_vpc_wide_settings/_vpc.hcl`

* The `splunk_cloud_forgecicd` module depends on tenant definitions.

  * To define tenants, follow: [docs/configurations/new\_tenant.md](../../docs/configurations/new_tenant.md)


---

## Deployment

Deploy all modules:

```bash
cd examples/deployments/forge-integrations/terragrunt/environments/prod/
terragrunt run-all plan
terragrunt run-all apply
```

Or deploy a specific module:

```bash
cd terragrunt/environments/prod/splunk_cloud_conf/
terragrunt plan
terragrunt apply
```

```bash
cd terragrunt/environments/prod/splunk_cloud_forgecicd/
terragrunt plan
terragrunt apply
```

Use whichever approach aligns with your workflow.
