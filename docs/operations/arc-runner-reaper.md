# ARC stale runner reaper

This is a cluster-wide remediation for ARC runners that become stuck after
accepting a GitHub Actions job. One CronJob runs in each enabled Forge EKS
cluster and automatically discovers every live ARC `AutoScalingRunnerSet` in
every namespace. It removes an `EphemeralRunner` only when the runner accepted a
job but never started `Runner.Worker` and its diagnostic log stopped advancing.

## Scope and safety model

The reaper is configured once in the Forge EKS module rather than once per
tenant. All ARC tenants and scale sets discovered in the cluster are included
by default - there is no tenant allowlist or opt-out. Blue and green clusters
have independent CronJobs and configuration.

Kubernetes requires every CronJob object to live in a namespace. Terraform
creates the configured namespace, `forge-system` by default, and places the
CronJob there. Its discovery and RBAC scope are cluster-wide, so it is not
limited to runners in that namespace.

The reaper is disabled by default at the cluster level. Enabling it still
defaults to observation only. In dry-run mode its ClusterRole cannot delete
`EphemeralRunner` objects, so changing an environment variable inside the pod
is not enough to turn observation into deletion.

Before deletion, all of these conditions must hold twice for the same namespace,
runner, and GitHub job ID, with a configurable delay between checks:

- the `EphemeralRunner` is in `Running` phase and has `status.jobId` set.
- its namespace and scale-set name match a live `AutoScalingRunnerSet`.
- the `EphemeralRunner` itself is at least 12 minutes old (15 minutes by
  default).
- a runner diagnostic log contains `Acknowledging runner request`.
- no `Runner.Worker` process is present.
- no `Worker_*.log` exists.
- the newest `Runner_*.log` has been silent for at least 12 minutes (15 minutes
  by default).

The reaper checks the oldest runners in each tenant first. It caps exec probes
at 50 per tenant and 500 cluster-wide by default. It caps deletions at one per
tenant and 20 cluster-wide per execution, preventing one broken tenant from
consuming the entire deletion budget. It deletes the `EphemeralRunner` custom
resource, not the pod, so ARC performs its normal GitHub deregistration and
Kubernetes cleanup before replenishing the scale set.

## Suggested rollout

First enable observation mode on an active non-production EKS cluster:

```hcl
runner_reaper = {
  enabled = true
  dry_run = true
  image   = "ghcr.io/cisco-open/forge-arc-runner-reaper:main"
}
```

Verify several scheduled executions and compare every `would-delete` result
with its runner pod and GitHub job. Then promote the reviewed change to an
active production cluster using an approved, mirrored image pinned by digest:

```hcl
runner_reaper = {
  enabled  = true
  dry_run  = false
  schedule = "*/15 * * * *"
  image    = "ghcr.io/cisco-open/forge-arc-runner-reaper@sha256:REPLACE_WITH_PUBLISHED_DIGEST"
}
```

Active mode is rejected during Terraform validation unless the image ends in a
SHA-256 digest. The image must contain `/bin/sh`, `kubectl`, and the process and
file-inspection utilities checked by the image smoke test. The official
`registry.k8s.io/kubectl` image is distroless and is not suitable by itself.
Forge builds a minimal shell-capable image from pinned Ubuntu and Kubernetes
image digests in `.docker/arc-runner-reaper/Dockerfile`.

Production enablement should use the normal pull-request, approval, plan review,
and EKS deployment path. If a manual validation CronJob exists, suspend and
remove it as part of the transition so two active reapers cannot overlap.

## Removing the reaper

To stop new runs immediately while preparing the infrastructure change, suspend
the CronJob:

```shell
kubectl --context <cluster-context> --namespace forge-system patch cronjob arc-runner-reaper \
  --type merge --patch '{"spec":{"suspend":true}}'
```

Use the configured namespace instead of `forge-system` if it was overridden.
Suspending the CronJob does not stop a Job that is already running. Delete any
active reaper Job if it must stop immediately:

```shell
kubectl --context <cluster-context> --namespace forge-system delete job \
  --selector app.kubernetes.io/name=arc-runner-reaper
```

For permanent removal, remove the `runner_reaper` block from the cluster
configuration or set `enabled = false`, then apply the EKS stack through the
normal deployment process. Review the plan before applying it. Terraform should
remove the CronJob, ConfigMap, service account, ClusterRole, ClusterRoleBinding,
and the namespace it created.

The module owns the namespace lifecycle, so do not configure the reaper to use a
namespace that contains unrelated resources. Deleting a Kubernetes namespace
also deletes everything inside it.

After the apply, verify that the namespace and cluster-wide RBAC resources are
gone:

```shell
kubectl --context <cluster-context> get namespace forge-system
kubectl --context <cluster-context> get clusterrole,clusterrolebinding \
  --selector app.kubernetes.io/name=arc-runner-reaper
```

The namespace command should return `NotFound` and the RBAC query should return
no resources. Repeat the removal for every cluster where the reaper was enabled.
Any manually created validation CronJob is outside Terraform and must be removed
separately.

## Drawbacks and residual risk

- With the 15-minute schedule, recovery occurs roughly 16–31 minutes after the
  runner log stops: the 15-minute stale threshold, up to 15 minutes before the
  next run, and the 60-second confirmation delay.
- The ClusterRole can exec into pods and delete `EphemeralRunner` objects in all
  namespaces. This broad permission is required for automatic all-tenant
  coverage and gives the component a cluster-wide blast radius.
- A single broken CronJob delays recovery for all tenants in that cluster. A
  failure while reading one tenant is logged, other tenants are still checked,
  and the Job exits unsuccessfully so monitoring can detect incomplete scans.
- On a very busy cluster, the per-tenant or cluster-wide probe cap may postpone
  detection. Raising the caps speeds detection but adds Kubernetes API and
  pod-exec load and can exceed the Job deadline.
- A compromised reaper image inherits the ClusterRole permissions. Use an
  approved private mirror and an immutable digest in active mode.
- CronJob failures and `deleted` events need monitoring. The implementation
  emits structured logs but does not add a platform alert.
- There remains a small check/delete race. A runner that recovers after the
  second check but immediately before deletion could be terminated. The
  12-minute minimum, 15-minute default, job-ID stability check, missing worker
  checks, and GitHub's 10-minute lost-contact timeout make that scenario
  unlikely, but they cannot make it impossible without confirming job state
  through the GitHub API.
- This mitigation depends on current runner log text, process naming, filesystem
  layout, and ARC CRD fields. Runner or ARC upgrades must be tested against it.

Disable and remove the reaper when it is no longer operationally necessary.
