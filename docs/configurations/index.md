# Forge Configuration Map

Use this section when you are turning the Forge examples into your own live
Terragrunt configuration. It is organized by deployment root so a platform
engineer can copy one root, change local values, and run plans without reading
the full module catalog first.

The main runtime path is `platform`. `infra`, `helpers`, and `integrations` are
added only when your operating model needs them.

______________________________________________________________________

## Pick the Path

| Goal                                             | Start here                                    | Deploy root                                    | Required?                       |
| ------------------------------------------------ | --------------------------------------------- | ---------------------------------------------- | ------------------------------- |
| Run GitHub Actions tenants on Forge              | [Platform](./deployments/platform.md)         | `examples/deployments/platform/terragrunt`     | Yes                             |
| Build the EKS foundation for ARC runners         | [Infra / EKS](./deployments/infra.md)         | `examples/deployments/infra/terragrunt`        | Only for ARC/Kubernetes runners |
| Add operational support modules                  | [Helpers](./deployments/helpers.md)           | `examples/deployments/helpers/terragrunt`      | Optional                        |
| Add webhook, Teleport, Splunk, or vendor modules | [Integrations](./deployments/integrations.md) | `examples/deployments/integrations/terragrunt` | Optional                        |

______________________________________________________________________

## Minimum Working Install

For the first useful deployment, keep the scope small:

1. Copy `examples/deployments/platform` into the repo where your company keeps
   Terragrunt live configuration.
1. Edit `_global.yml`, `_environment.yml`, `_region.hcl`, and `_vpc.yml` for
   your account, region, VPC, subnets, and runner group suffix.
1. Add one tenant under
   `environments/prod/regions/eu-west-1/vpcs/main/tenants/<tenant_name>`.
1. Put one EC2 runner spec or one ARC runner spec in the tenant `config.yml`.
1. Deploy that tenant.
1. Add the other runner lane, helpers, and integrations only after the first
   runner path works.

```bash
cd examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme
terragrunt plan
terragrunt apply
```

______________________________________________________________________

## What You Usually Change

| File                                                                                                                 | Change                                                                                      |
| -------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `examples/deployments/*/release_versions.yml`                                                                        | Module repository, version, and `module_path` metadata for that deployment category.        |
| `examples/deployments/*/terragrunt/_global_settings/_global.yml`                                                     | Team, product, project, GitHub org, and owner email defaults.                               |
| `examples/deployments/*/terragrunt/environments/prod/_environment_wide_settings/_environment.yml`                    | AWS account ID, default region, AWS profile, remote state, and environment-level naming.    |
| `examples/deployments/platform/terragrunt/environments/prod/regions/<region>/_region_wide_settings/_region.hcl`      | Region alias used in runner labels and names.                                               |
| `examples/deployments/platform/terragrunt/environments/prod/regions/<region>/vpcs/<vpc>/_vpc_wide_settings/_vpc.yml` | VPC alias, VPC ID, Lambda subnets, runner subnets, and optional ARC cluster name.           |
| `examples/deployments/platform/terragrunt/environments/prod/regions/<region>/vpcs/<vpc>/tenants/<tenant>/config.yml` | GitHub App IDs, tenant IAM roles, ECR registries, EC2 runner specs, and optional ARC specs. |

Each category also has templates under `examples/templates/<category>`. Use the
templates for new files, then keep the deployed examples as your working
reference.

______________________________________________________________________

## Common Follow-Up Tasks

| Task                              | Doc                                                        | Why it is outside this section                                                |
| --------------------------------- | ---------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Add a tenant                      | [Tenant Onboarding](../operations/tenant-onboarding.md)    | Tenant onboarding is an operations workflow using the platform root.          |
| Move ARC tenants between clusters | [Move ARC Tenants](../operations/move-arc-tenants.md)      | Cluster moves are controlled day-2 operations, not a new deployment category. |
| Build or update runner AMIs       | [Runner Images](../operations/runner-images.md)            | Image builds are artifact operations consumed by platform configs.            |
| Deploy Splunk                     | [Splunk Integration](../integrations/splunk.md)            | Splunk is optional and has its own credential flow.                           |
| Check module ordering             | [Module Dependencies](../reference/module-dependencies.md) | Dependency rules are reference material shared by all deployment roots.       |

______________________________________________________________________

## Skip Rules

- EC2-only deployment: skip `examples/deployments/infra`, `arc_runner_specs`,
  `arc_cluster_name`, and Kubernetes integrations.
- No Splunk: skip `examples/deployments/integrations/terragrunt/**/splunk_*`
  and [Splunk Secrets](../integrations/splunk-secrets.md).
- Existing EKS: skip `modules/infra/eks` and point ARC configuration at the
  existing cluster.
- Existing buckets, ECR, AMI sharing, or service-linked roles: skip the matching
  helper module and feed those externally managed values into the platform or
  integration config.

______________________________________________________________________

## Deeper References

- [Platform Engineer Quick Start](../getting-started/platform-engineer.md)
- [Deployment Scenarios](./deployments/index.md)
- [Module Dependencies](../reference/module-dependencies.md)
- [Module Layout](../reference/module-layout.md)
- [Operations](../operations/index.md)
