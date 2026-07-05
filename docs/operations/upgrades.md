# Upgrades

Forge upgrades are mainly release metadata and tenant rollout work.

## What Changes

| Area                          | File or repo                                      |
| ----------------------------- | ------------------------------------------------- |
| Forge module refs             | `release_versions.yml` or `release_versions.yaml` |
| Tenant runner settings        | `runner_settings.hcl`                             |
| AMI IDs                       | image repo output and tenant specs                |
| ARC controller and scale sets | platform release and EKS compatibility            |
| Integration modules           | integration release file and secrets              |
| Reusable actions              | operations repo workflow refs                     |

## Upgrade Flow

1. Update one non-production release file to the new Forge ref.
1. Run plan for helpers, infra, platform, and integrations.
1. Apply one tenant or one example deployment.
1. Run smoke workflows on EC2 and ARC if both lanes are enabled.
1. Roll forward by environment.
1. Keep the previous Forge ref and AMI IDs available for rollback.

## ARC/EKS Blue-Green Upgrade

Use the blue-green flow when the change touches the EKS foundation or ARC
runtime: EKS version, node AMIs, Karpenter, Calico, EBS CSI, Pod Identity, ARC
controller, ARC scale-set templates, or cluster-level access integrations.

The operating model is:

- two EKS folders per region, usually `blue` and `green`
- one cluster marked active with `is_active: true`
- one cluster marked inactive with `is_active: false`
- tenant configs pointing `arc_cluster_name` at the active cluster
- tenant configs keeping `migrate_arc_cluster: false` except during an
  intentional tenant move

Before starting:

1. Disable or pause normal promotion and regression workflows for the tenant
   and infra repos so another apply cannot race the upgrade.
1. Discover the active and inactive EKS folders and fail if there is not exactly
   one active and one inactive cluster.
1. Validate every ARC tenant in the target environment and region points at the
   active cluster.
1. Confirm the scripts are available:
   `scripts/reinstall-eks-with-deps.sh` and `scripts/migrate-tenant.sh`.

Run the region in this order:

1. Destroy the inactive EKS cluster with dependents:

   ```bash
   cd terraform/environments/prod/regions/eu-west-1/eks/green
   /path/to/forge/scripts/reinstall-eks-with-deps.sh destroy
   ```

1. Recreate the inactive cluster from the updated module refs and config:

   ```bash
   yq e -i '.is_active = true' config.yaml
   /path/to/forge/scripts/reinstall-eks-with-deps.sh create
   ```

1. Move tenants to the rebuilt cluster one at a time:

   ```bash
   /path/to/forge/scripts/migrate-tenant.sh \
     --tf-dir terraform/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme
   ```

1. Run ARC smoke workflows for each moved tenant.

1. Destroy and recreate the previous active cluster with the same dependency
   script.

1. Move tenants again only when your operating model requires tenants to finish
   on the active color after both clusters have been rebuilt.

1. Reapply cluster access integrations such as Teleport if your installation
   deploys them.

1. Re-enable the paused workflows.

For multi-environment operations, run the same reusable workflow sequentially:
dev first, then production regions one at a time. Keep tenant moves
`max-parallel: 1` so each tenant has a narrow, observable runner gap.

See [Move ARC Tenants](move-arc-tenants.md) for the per-tenant mechanics and
the workflow automation shape.

## Maintenance Cadence

| Cadence   | Check                                                                                                  | Where                                             |
| --------- | ------------------------------------------------------------------------------------------------------ | ------------------------------------------------- |
| Weekly    | Example deployments still apply and destroy in dependency order.                                       | `forge-examples-iac-aws` workflow                 |
| Weekly    | Cloud Custodian reports no stale runner instances, old AMIs, or unowned snapshots.                     | `cloud-custodian` repo                            |
| Monthly   | Forge module refs, reusable action refs, and container tags have Renovate coverage.                    | `release_versions.yml`, workflows, Dockerfiles    |
| Monthly   | Runner AMIs still have an active and rollback version.                                                 | image repos and tenant `runner_settings.hcl`      |
| Monthly   | ECR lifecycle policies preserve rollback tags and remove unreferenced tags.                            | `modules/helpers/ecr` or external registry policy |
| Quarterly | ARC/EKS blue-green upgrade path is still executable in non-production.                                 | [Move ARC Tenants](move-arc-tenants.md)           |
| Quarterly | Tenant IAM roles, ECR access, GitHub App installations, and runner labels still match current tenants. | tenant IaC repo                                   |

Use these commands as the starting point for a release review:

```bash
rg 'ref: v|ref=v|module_path:|source: git::' release_versions.y*ml terraform examples
```
