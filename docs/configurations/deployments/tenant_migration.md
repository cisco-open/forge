# Migrating a Tenant Between EKS Clusters with ForgeMT + ARC + Terragrunt

## Tenant Migration Steps

1. **Identify Current and Target Clusters**

   * Read the current cluster name from the tenant config file (like `arc_cluster_name: srea-forge-euw1-prod-green`).
   * Determine the target cluster by switching the suffix from `-green` to `-blue` or vice versa.

2. **Scale Down Runner Sets in the Source Cluster**

   * List all runner sets defined under `arc_runner_specs`.
   * For each runner set, scale down both minimum and maximum runners to zero on the source cluster to stop all active runner pods.

3. **Disable ARC on the Source Cluster**

   * Update the tenant’s config by setting a migration flag (e.g., `migrate_arc_cluster: true`) which disables ARC resources on the source cluster.
   * Apply this config change so the Terraform/Terragrunt deployment removes ARC for this tenant in the source cluster.

4. **Enable ARC on the Target Cluster**

   * Change the migration flag back to false (`migrate_arc_cluster: false`).
   * Update the `arc_cluster_name` to the target cluster (e.g., switching from `srea-forge-euw1-prod-green` to `srea-forge-euw1-prod-blue`).
   * Deploy ARC resources in the target cluster with these config changes.

5. **Wait for Runner Pods to Stabilize**

   * Verify that runner pods have fully terminated on the source cluster.
   * Confirm runner pods are healthy and running on the target cluster.

---

## Automation Script for Tenant Migration

To simplify and standardize the migration process, an automation script is available that performs all the steps described above:

* **Detects the current cluster** from the tenant configuration.
* **Determines the target cluster** by toggling the blue/green suffix.
* **Scales down runner sets** in the source cluster gracefully.
* **Updates the migration flag and cluster name** in the tenant config.
* **Applies Terraform/Terragrunt changes** to disable ARC on the old cluster and enable it on the new one.
* **Waits for runner pods to terminate** before switching, ensuring a clean handoff.
* Provides clear logging at each step for easy monitoring.

### Usage Example

Run the script by specifying the tenant’s Terraform directory and Kubernetes context alias:

```
./scripts/migrate-tenant.sh --tf-dir /full/path/to/tenant_dir --context <kube-context-alias>
```

The script will handle the rest, reducing human error and speeding up the migration process.
