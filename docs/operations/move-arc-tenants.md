# Move ARC Tenants Between EKS Clusters

Use this when ARC tenants need to move between blue and green EKS clusters. The
same mechanics support EKS and ARC upgrades: rebuild the cluster that is not
serving tenants, move tenants to it, then rebuild the other cluster.

This is not a normal tenant onboarding step. Run it only for planned cluster
work or recovery from a cluster-level issue.

## Preconditions

- `arc_cluster_name` ends in `-blue` or `-green`.
- `migrate_arc_cluster` is `false` before the move starts.
- The source and target EKS clusters exist in Terraform/Terragrunt config.
- The operator or workflow can update kubeconfig for the source cluster.
- The operator or workflow can run targeted Terragrunt applies for the tenant.
- No normal promotion workflow is applying the same tenant at the same time.

## Move Steps

1. **Identify Current and Target Clusters**

- Read the current cluster name from the tenant config file, for example
  `arc_cluster_name: forge-euw1-prod-green`.
- Determine the target cluster by switching the suffix from `-green` to
  `-blue` or vice versa.

2. **Scale Down Runner Sets in the Source Cluster**

- List all runner sets defined under `arc_runner_specs`.
- For each runner set, scale down both minimum and maximum runners to zero on
  the source cluster to stop all active runner pods.

3. **Disable ARC on the Source Cluster**

- Update the tenant's config by setting `migrate_arc_cluster: true`, which
  disables ARC resources on the source cluster.
- Apply this config change so the Terraform/Terragrunt deployment removes ARC
  for this tenant in the source cluster.

4. **Enable ARC on the Target Cluster**

- Change `migrate_arc_cluster` back to false (`migrate_arc_cluster: false`).
- Update the `arc_cluster_name` to the target cluster, for example from
  `forge-euw1-prod-green` to `forge-euw1-prod-blue`.
- Deploy ARC resources in the target cluster with these config changes.

5. **Wait for Runner Pods to Stabilize**

- Verify that runner pods have fully terminated on the source cluster.
- Confirm runner pods are healthy and running on the target cluster.

______________________________________________________________________

## Automation Script

To simplify and standardize the cluster move, use:

```bash
./scripts/migrate-tenant.sh --tf-dir /full/path/to/tenant_dir
```

The script performs these steps:

- **Detects the current cluster** from the tenant configuration.
- **Determines the target cluster** by toggling the blue/green suffix.
- **Renders Terragrunt inputs** to find the AWS profile, region, and ARC
  cluster name.
- **Updates kubeconfig** for the source cluster with an alias that includes the
  cluster, profile, and region.
- **Scales down runner sets** in the source cluster gracefully.
- **Sets `migrate_arc_cluster: true`** and applies `module.arc_runners` against
  the source cluster to remove the tenant ARC footprint there.
- **Points `arc_cluster_name` at the target cluster** and applies
  `module.arc_runners` while `migrate_arc_cluster` is still true, which keeps
  the target side clean before enabling it.
- **Sets `migrate_arc_cluster: false`** and applies `module.arc_runners` again
  to create the tenant ARC resources on the target cluster.
- **Applies `module.forge_trust_validator`** so tenant trust checks are current
  after the move.
- **Leaves the tenant config pointing at the target cluster** with
  `migrate_arc_cluster: false`.

### Usage Example

Run the script by specifying the tenant Terraform directory:

```bash
./scripts/migrate-tenant.sh --tf-dir /full/path/to/tenant_dir
```

After the script finishes, run a tenant ARC smoke workflow and verify:

```bash
kubectl get autoscalingrunnersets -n <tenant>
kubectl get pods -n <tenant>
terragrunt plan --working-dir /full/path/to/tenant_dir
```

The plan should not try to recreate the tenant on the source cluster.

## Workflow Automation Pattern

For production upgrades, put the tenant move behind a GitHub Actions workflow
instead of running every command locally. The reusable workflow should do this:

1. Discover the active and inactive EKS folders from `is_active` in each
   cluster `config.yaml`.
1. Fail if there is not exactly one active and one inactive cluster.
1. Validate all tenants currently point at the active cluster.
1. Destroy and recreate the inactive cluster by running
   `scripts/reinstall-eks-with-deps.sh`.
1. Build a tenant matrix from the tenant directories.
1. Move tenants with `scripts/migrate-tenant.sh`, using `max-parallel: 1`.
1. Destroy and recreate the previous active cluster.
1. Optionally move tenants back to the final active cluster.
1. Reapply cluster access integrations such as Teleport when used.

Use a top-level workflow to sequence environments and regions. A practical
order is:

```text
dev/eu-west-1 -> prod/eu-west-1 -> prod/us-east-1 -> prod/us-west-2
```

Keep a workflow-level concurrency group and temporarily disable normal
promotion workflows for the affected IaC repos while the blue-green run is in
progress.

## Safety Rules

- Do not leave `migrate_arc_cluster: true` in a tenant config.
- Do not move tenants in parallel until the process is proven for your cluster
  and runner capacity model.
- Do not destroy the source cluster until moved tenants have completed smoke
  workflows on the target cluster.
- Do not run the normal tenant promotion workflow during the cluster move.
- Keep the previous runner container image and EKS module refs available until
  the target cluster is proven.
- If a move fails after source cleanup, fix the target cluster and rerun the
  tenant script from the same tenant directory.

## Related Upgrade Flow

Use [Upgrades](upgrades.md) for the full ARC/EKS blue-green upgrade sequence.
