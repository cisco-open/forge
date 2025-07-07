# 🧩 Infra Forge Deployment Example

This folder provides a complete, multi-tenant **Forge** deployment using **Terragrunt** for layered configuration.

> **⚠️ Important:** Replace all `<ADD YOUR VALUE>` placeholders with actual values (e.g., tokens, ARNs, config IDs) before deploying.

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
terragrunt apply --all terragrunt/environments/prod/
```

> **Tip:** Always run `terragrunt plan --all` first to validate changes before applying.
