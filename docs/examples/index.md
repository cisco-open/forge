# Examples

ForgeMT examples are meant to be functional. Copy them into your operating
repos, replace the config values with real AWS and GitHub values, then run
Terragrunt from the stack folder. They are grouped the same way as the modules
so a platform engineer can skip categories that are not part of the company
design.

## Example Roots

| Scenario                  | Copy from                                                | Change first                                                                | Related docs                                                                 |
| ------------------------- | -------------------------------------------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| First tenant runner lane  | `examples/deployments/platform`                          | tenant `config.yml`, `runner_settings.hcl`, `_global.yml`, release versions | [Configure Platform](../getting-started/configure-platform.md)               |
| ARC runners on EKS        | `examples/deployments/infra`                             | EKS `config.yml`, region settings, then tenant `arc_runner_specs`           | [Configure Infra](../getting-started/configure-infra.md)                     |
| Account helpers           | `examples/deployments/helpers`                           | helper-specific `config.yml` files and account settings                     | [Configure Helpers](../getting-started/configure-helpers.md)                 |
| Splunk, Teleport, relay   | `examples/deployments/integrations`                      | only the integration folders your company uses                              | [Configure Integrations](../getting-started/configure-integrations.md)       |
| Reusable tenant templates | `examples/templates/platform`                            | tenant folder names, VPC settings, runner labels, allowed AWS roles         | [First Tenant](../getting-started/first-tenant.md)                           |
| Weekly validation repo    | `docs/operations/repo-blueprints/forge-examples-iac-aws` | workflow schedule, AWS role, region matrix, category matrix                 | [Weekly Example Deployments](../operations/workflows/example-deployments.md) |
| Platform operating repos  | `docs/operations/repo-blueprints`                        | repository names, secrets, role names, image names, and release metadata    | [Repo Blueprints](../operations/repo-blueprints/index.md)                    |

## Copy Pattern

The examples are designed to move into a company-owned operations repo.

```bash
mkdir -p terraform
cp -R examples/deployments/platform terraform/platform
cp -R examples/templates/platform terraform/templates-platform
```

Then edit the copied files, not the Forge source checkout:

```text
terraform/platform/release_versions.yml
terraform/platform/terragrunt/_global_settings/_global.yml
terraform/platform/terragrunt/environments/<env>/_environment_wide_settings/_environment.yml
terraform/platform/terragrunt/environments/<env>/regions/<region>/vpcs/<vpc>/tenants/<tenant>/config.yml
terraform/platform/terragrunt/environments/<env>/regions/<region>/vpcs/<vpc>/tenants/<tenant>/runner_settings.hcl
```

If your operating repo uses a different layout, keep the same idea: one release
metadata file, shared environment settings, and small tenant folders.

For the full first-run sequence, use
[Minimal Install](../getting-started/minimal-install.md).

## Minimum First Run

For the first tenant runner lane:

1. copy `examples/deployments/platform`
1. set the Forge module ref in `release_versions.yml`
1. set GitHub App, region, VPC, subnet, tenant, tags, and runner image values
1. keep one EC2 runner spec or one ARC runner spec
1. remove runner specs for foundations that are not ready yet
1. run a plan from the tenant folder

```bash
cd terraform/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme
terragrunt init
terragrunt plan
```

After apply, test with a workflow that uses the exact runner label from
`runner_settings.hcl`.

## Release Versions

Each deployment category has its own release metadata file:

```text
examples/deployments/helpers/release_versions.yml
examples/deployments/infra/release_versions.yml
examples/deployments/platform/release_versions.yml
examples/deployments/integrations/release_versions.yml
```

During branch validation, point refs at the active branch. For a released
environment, pin a release tag or commit SHA.

```yaml
module_path: modules/platform/forge_runners
ref: <forge-release-tag-or-commit>
```

Keep release metadata reviewable. A tenant onboarding PR should show exactly
which module ref and module path it will deploy.

## Weekly Validation Matrix

Weekly tests should apply the enabled categories in dependency order:

```text
helpers -> infra -> platform -> integrations
```

Destroy in reverse order:

```text
integrations -> platform -> infra -> helpers
```

If the company does not use Splunk, Teleport, ARC, or a helper category, remove
that category from the weekly matrix. A skipped integration is cleaner than a
failing placeholder deployment.

## What Not To Copy

Do not copy every example by default. Copy only the categories you operate:

- copy `platform` for every Forge installation
- copy `infra` only when Forge owns EKS for ARC
- copy `helpers` only for account preparation or day-2 operations you need
- copy `integrations` only for systems your company uses
- copy `repo-blueprints` when you are ready to build the full operating model
