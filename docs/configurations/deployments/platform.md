# Platform Deployment

This is the main Forge runtime path. It deploys tenant runner control planes
through `modules/platform/forge_runners`, which can create EC2 runners and ARC
runner scale sets.

Deploy root:

```text
examples/deployments/platform/terragrunt
```

Skip the infra, helpers, and integrations examples until this path can deploy
one tenant successfully.

______________________________________________________________________

## What Is in the Example

| Path                                                                        | Purpose                                                                  |
| --------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `_global_settings/_global.yml`                                              | Team, product, project, GitHub org, and owner defaults.                  |
| `_global_settings/tenant.hcl`                                               | Shared Terragrunt translation from tenant `config.yml` to module inputs. |
| `environments/prod/_environment_wide_settings/_environment.yml`             | AWS account, default region, remote state, and naming suffixes.          |
| `environments/prod/regions/eu-west-1/_region_wide_settings/_region.hcl`     | Region and short region alias used in labels and names.                  |
| `environments/prod/regions/eu-west-1/vpcs/main/_vpc_wide_settings/_vpc.yml` | VPC ID, Lambda subnets, runner subnets, VPC alias, and cluster name.     |
| `environments/prod/regions/eu-west-1/vpcs/main/tenants/acme/config.yml`     | Tenant GitHub App, IAM, EC2 runner specs, and optional ARC specs.        |
| `release_versions.yml`                                                      | Module source, version, and `module_path` metadata.                      |

The example uses `prod`, `eu-west-1`, `main`, and `acme` as copyable defaults.
Rename them to match your account naming.

______________________________________________________________________

## First Install Checklist

1. Copy `examples/deployments/platform` into the repo where your live
   Terragrunt configuration belongs.
1. Edit `terragrunt/_global_settings/_global.yml`.
1. Edit `terragrunt/environments/prod/_environment_wide_settings/_environment.yml`.
1. Edit `terragrunt/environments/prod/regions/eu-west-1/_region_wide_settings/_region.hcl`.
1. Edit `terragrunt/environments/prod/regions/eu-west-1/vpcs/main/_vpc_wide_settings/_vpc.yml`.
1. Add or edit one tenant under
   `terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/<tenant>`.
1. Confirm `release_versions.yml` points at the Forge version and module paths
   you intend to consume.

For a new tenant, follow
[Tenant Onboarding](../../operations/tenant-onboarding.md).

______________________________________________________________________

## Deploy One Tenant

Prefer a single tenant apply for the first rollout:

```bash
cd examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme
terragrunt plan
terragrunt apply
```

After the first tenant works, you can plan the whole environment:

```bash
cd examples/deployments/platform/terragrunt/environments/prod
terragrunt plan --all
```

Run `terragrunt apply --all` only when your repo workflow allows environment
wide applies.

______________________________________________________________________

## EC2 Only vs ARC

For EC2-only tenants:

- Keep `arc_runner_specs: {}`.
- Keep `arc_cluster_name: ''`.
- Skip `examples/deployments/infra`.
- Skip Kubernetes and EKS integrations.

For ARC tenants:

- Deploy or provide an EKS cluster first.
- Add `arc_runner_specs` to the tenant `config.yml`.
- Set `arc_cluster_name` to the target EKS cluster.
- Confirm Kubernetes providers can authenticate before applying the tenant.

______________________________________________________________________

## Validation

Before opening a rollout PR, run the checks your consumer repo uses. For the
example itself:

```bash
terragrunt hclfmt --terragrunt-check
cd examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme
terragrunt validate
terragrunt plan
```

Expected outcome:

- The plan creates or updates only the target tenant resources.
- The GitHub App SSM parameters exist.
- The runner group name matches
  `<tenant>-<region_alias>-<vpc_alias>-<runner_group_name_suffix>`.
