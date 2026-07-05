# Repository Layout

Forge has two different repository concerns:

1. This source repo, which contains modules, examples, docs, and tests.
1. Your operating repos, which deploy Forge, build images, run cleanup jobs, and
   test examples on a schedule.

## Forge Source Repo

```text
modules/
  platform/      Runtime modules for Forge runners.
  infra/         Foundation infrastructure, currently EKS for ARC.
  helpers/       Account and operations helpers.
  integrations/  Optional vendor or external integrations.

examples/deployments/
  helpers/       Optional helper deployments.
  infra/         EKS foundation deployment.
  platform/      Tenant runner deployment.
  integrations/  Optional integration deployments.

examples/templates/
  helpers/
  infra/
  platform/
  integrations/
```

## Operating Repo Set

A platform team usually needs more than one repo because AMI builds, container
builds, tenant IaC, infra IaC, and scheduled cleanup have different owners and
release cycles.

Use [Operations Repo Blueprints](../operations/repo-blueprints/index.md) when
you want copyable repo skeletons for:

- runner base images
- runner custom images
- operational containers
- Renovate config
- Cloud Custodian policies
- Forge tenants IaC
- Forge infra/helper IaC
- weekly example deployments
- reusable GitHub Actions

You can merge these repos in a small organization, but keep the folder
boundaries. A Packer change should not require touching tenant Terragrunt, and a
Splunk change should not be in the critical path for companies that do not use
Splunk.
