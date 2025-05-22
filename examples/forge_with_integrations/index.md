# 🧩 Forge Multi-Tenant Deployment Example

This folder provides a complete, multi-tenant **Forge** deployment using **Terragrunt** for layered configuration. It integrates with services like **Splunk**, **Teleport**, and others to enable observability, secure access, and automation.

> **⚠️ Important:** Replace all `<ADD YOUR VALUE>` placeholders with actual values (e.g., tokens, ARNs, config IDs) before deploying.

---

## 📦 Module Overview

The following modules are deployed as part of this configuration:

| Module                      | Description                                                                                                             |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `forge_runners`             | Provisions ephemeral GitHub Actions runners (EC2 and EKS), with tenant isolation, autoscaling, and lifecycle automation |
| `teleport`                  | Integrates Teleport for secure shell access, auditing, and session recording                                            |
| `splunk_cloud_data_manager` | Configures Splunk Cloud Data Manager for ingesting logs and events                                                      |
| `splunk_cloud_conf_shared`  | Applies shared Splunk Observability configuration across environments (dashboards, alert templates, etc.)               |

---

## ⚠️ Prerequisites

Before deploying, ensure:

* All `<ADD YOUR VALUE>` placeholders are replaced
* Secrets are created in **AWS Secrets Manager**
  → See [`docs/configurations/secrets.md`](../../docs/configurations/secrets.md)
* Infra dependencies (e.g., IAM, S3) are in place
  → See [`docs/configurations/dependency.md`](../../docs/configurations/dependency.md)

---

## 🚀 Deployment

### Apply a Single Module

```bash
terragrunt apply terragrunt/environments/prod/regions/eu-west-1/vpcs/sl/tenants/forge/runner_settings.hcl
```

### Apply All Modules Recursively

```bash
terragrunt run-all apply terragrunt/environments/prod/
```

> **Tip:** Always run `terragrunt run-all plan` first to validate changes before applying.
