# First Tenant

Use this as the copy/change/run path for the first Forge tenant.

## Copy The Template

Copy:

```text
examples/templates/platform/tenant
```

Into the platform deployment tree:

```text
examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/<tenant>
```

## Change These Values

| File                  | Change                                                                                                           |
| --------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `config.yml`          | GitHub org/app values, tenant IAM roles, ECR registries, EC2 specs, ARC specs, AMI owner/name, and cluster name. |
| `runner_settings.hcl` | Label generation, runner group naming, module inputs, and include paths when your folder depth differs.          |
| `terragrunt.hcl`      | Include paths only if your folder depth differs from the example.                                                |

## First Plan

```bash
cd examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/<tenant>
terragrunt init
terragrunt plan
```

## First Workflow

Give the tenant a minimal workflow after apply:

```yaml
---
name: Forge smoke test

on:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  smoke:
    runs-on:
      - self-hosted
      - type:small
      - x64
      - ec2
      - tnt:<tenant>
    steps:
      - run: echo "Forge runner is online"
```

If the job stays queued, check GitHub App installation, runner group access,
tenant labels, and whether the runner module created the expected scale set or
EC2 runner group.

For the full operator workflow, including GitHub App permissions, SSM key
setup, ARC notes, and common failures, use
[Tenant Onboarding](../operations/tenant-onboarding.md).
