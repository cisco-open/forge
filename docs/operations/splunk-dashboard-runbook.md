# Splunk Dashboard Runbook

Use this page when you need to understand Forge health from Splunk without
already knowing the Forge internals.

Forge uses two Splunk surfaces:

- Splunk Cloud log dashboards from `modules/integrations/splunk_cloud_conf_shared`.
- Splunk Observability metrics dashboards from `modules/integrations/splunk_o11y_conf_shared`.

Always check log freshness before treating an empty dashboard as proof that
Forge is healthy. Empty can mean healthy, but it can also mean ingestion,
field extraction, or dashboard deployment is broken.

## Severity Language

Use the same words in incidents, tickets, and handovers.

| Severity   | Meaning                                                                                                                                     |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Normal     | Data is flowing, failures are isolated or expected, and runner or job behavior matches normal usage.                                        |
| Warning    | Something is unusual, noisy, stale, slow, or concentrated in one tenant or repository, but broad Forge impact is not proven.                |
| Problem    | A tenant, runner group, pipeline stage, AWS integration, or Forge automation is likely broken and needs action.                             |
| Apocalypse | Multiple tenants, regions, runner modes, or core Forge control-plane flows are failing, or telemetry itself is gone so operators are blind. |

Initial thresholds:

- Queue `p95_queue_sec` under 300 seconds is usually normal.
- Queue `p95_queue_sec` over 600 seconds is warning.
- Queued jobs over 15 minutes are problem.
- Queued jobs over 30 to 60 minutes across many tenants are apocalypse.
- One missing field or quiet sourcetype is warning.
- Missing runner, webhook, or CloudWatch data for active tenants is problem.
- Broad event-volume collapse is apocalypse.
- One tenant `AccessDenied` is problem for that tenant.
- Many tenants failing `AssumeRole` together is apocalypse.

## Which Dashboard First

| Symptom                                               | Start here                                 | Then open                                                                                                    |
| ----------------------------------------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| You do not know what is wrong.                        | Forge Troubleshooting                      | Forge Ingestion Quality, Forge Runner Capacity, Forge Lambda Operations                                      |
| Jobs wait for a runner.                               | Forge Runner Capacity                      | Forge GitHub Webhook Workflow Job Events, Forge Runner Control Plane Health, EC2 or ARC lifecycle dashboards |
| EC2 runner never comes online.                        | Forge EC2 Runner Lifecycle                 | Forge Runner Control Plane Health, EC2 scale-up failure dashboards, Forge Lambda Operations                  |
| ARC `dind` job fails or Docker daemon is unavailable. | Forge ARC DIND Runner Lifecycle            | Forge Kubernetes Storage and Network, Runner K8S Observability                                               |
| ARC `k8s` job pod is stuck, pending, or missing PVCs. | Forge ARC K8S Runner Lifecycle             | Forge Kubernetes Storage and Network, Runner K8S Observability                                               |
| Workflow job exists but logs are missing.             | Forge Webhook Job Log Pipeline             | Forge Ingestion Quality, Forge CI Job Details, Forge Tenant Logs                                             |
| Tenant asks for raw logs.                             | Forge Tenant Logs                          | Forge Ingestion Quality, Forge Webhook Job Log Pipeline                                                      |
| AWS role assumption fails from a runner.              | Forge Trust Failures                       | Forge Tenant Logs, Forge Lambda Operations, Forge Troubleshooting                                            |
| A dashboard looks empty or wrong.                     | Forge Ingestion Quality                    | Splunk deployment docs, source field extraction config                                                       |
| Stuck workflow redelivery is suspected.               | Forge Stuck Workflow Job Dispatcher Health | Forge Stuck Workflow Job Dispatcher Debug, Forge GitHub Webhook Workflow Job Events                          |
| Cost or adoption is the question.                     | Forge Impact, Billing, or OpenCost         | Runner EC2 Observability, Runner K8S Observability                                                           |

## Log Dashboards

### Forge Troubleshooting

Purpose: first dashboard when the symptom is unclear. It combines runner,
Lambda, trust, ingestion, Kubernetes, queue, and EC2 symptom panels.

Normal: event volume exists, errors are empty or isolated, queue and duration
are not dominated by one runner group, and trust, Lambda, and Kubernetes tables
are quiet.

Problem: one tenant, repository, or runner group dominates queue time, Lambda
errors, trust failures, or Kubernetes event categories.

Apocalypse: many sections are noisy together, or ingestion panels show missing
data while users report failures.

Action: identify the first failing boundary, then move to the narrower
dashboard. If data is missing, go to Forge Ingestion Quality before diagnosing
Forge behavior.

### Forge Ingestion Quality

Purpose: prove whether Splunk data is trustworthy.

Normal: expected sourcetypes are current and key fields such as
`forgecicd_tenant`, source, repository or job identifiers, and log type are
present.

Problem: malformed events, missing structured fields for active sources, or a
sourcetype that should be active goes stale.

Apocalypse: runner logs, webhook events, CloudWatch logs, or structured job JSON
disappear broadly.

Action: check source inventory and missing fields before blaming EC2, ARC, or
GitHub. Field names are an operational contract for the other dashboards.

### Forge Runner Capacity

Purpose: show job queue pressure and runner pool state across EC2 and ARC.

Normal: p95 queue is under about 5 minutes, there are few or no jobs over 10
minutes, ARC runner sets change between pending and running, and EC2 pool
symptoms are quiet.

Problem: one tenant or runner group has `queue_ge_10m`, p95 queue above 10
minutes, many failed jobs, or EC2 symptoms such as disk full, OOM, SSM
credential issues, permission denied, or connection timeout.

Apocalypse: many tenants have high queue time, or ARC and EC2 capacity signals
are flat while jobs continue queueing.

Action: if pressure is EC2, open Forge EC2 Runner Lifecycle and the EC2 scale-up
failure dashboards. If pressure is ARC, open ARC lifecycle and Kubernetes
Storage and Network. If only one repository or workflow is affected, check CI
Job Details and the tenant workflow labels.

### Forge GitHub Webhook Workflow Job Events

Purpose: inspect GitHub `workflow_job` webhook events by tenant, repository,
workflow, branch, labels, status, and conclusion.

Normal: queued, in-progress, and completed events appear in expected ratios.
Failures and cancellations are explainable by tenant workloads.

Problem: queued jobs over 15 minutes, failures concentrated in one tenant,
repository, or workflow, or missing lifecycle progression.

Apocalypse: `workflow_job` events stop arriving broadly, or queued jobs
accumulate across tenants with no matching dispatch or runner activity.

Action: for long-queued EC2 jobs, check dispatch logs and scale-up. For
non-EC2 queued jobs, check ARC listener, ARC manager, and Kubernetes scheduling.
For missing webhook events, check GitHub App installation and webhook delivery.

### Forge Webhook Job Log Pipeline

Purpose: verify the path from GitHub `workflow_job` event to archived job logs
and Splunk ingestion.

Normal: dispatcher enqueue counts, archived JSON counts, pipeline trend, and
ingestion data move together. DLQ redrive is quiet.

Problem: dispatcher enqueues but archiver errors grow, DLQ redrive appears
repeatedly, or structured JSON is much lower than raw logs for active jobs.

Apocalypse: dispatcher, archiver, S3, or Splunk ingestion stops broadly.

Action: identify the broken stage. If GitHub webhook is missing, use Forge
GitHub Webhook Workflow Job Events. If data is archived but not searchable, use
Forge Ingestion Quality.

### Forge CI Job Details

Purpose: inspect job execution from structured GitHub job log JSON.

Normal: structured job JSON is present for recent jobs, queue and duration
values are non-negative, and runner type usage matches known tenant workflows.

Problem: negative queue time indicates data quality trouble. Long duration or
queue time concentrated in a workflow needs tenant or workflow triage.

Apocalypse: structured job JSON disappears broadly.

Action: filter by tenant, repository, workflow, and time window. For missing
data, go to Webhook Job Log Pipeline and Ingestion Quality.

### Forge Tenant Logs

Purpose: tenant-focused raw log search.

Normal: the selected tenant and log type return current events for active jobs
or platform components.

Problem: the tenant has active jobs but no logs, or filters do not return
expected fields.

Apocalypse: many tenants lose log visibility.

Action: use this dashboard for raw evidence, then move to a specific dashboard
for interpretation. If logs are missing, use Ingestion Quality and Webhook Job
Log Pipeline.

### Forge EC2 Runner Lifecycle

Purpose: inspect EC2 runner webhook, scale, AMI, SSM, user-data, hook, runner
diagnostics, and instance tagging signals.

Normal: scale and lifecycle Lambda activity is present, runner versions are
expected, runner log symptoms are low, and AMI or SSM update failures are empty.

Problem: AMI or SSM update failures, runner hook failures, user-data errors,
scale capacity errors, AWS API errors, or repeated fatal, OOM, disk, or
permission symptoms.

Apocalypse: EC2 scale-up or registration fails across multiple tenants or
regions.

Action: decide whether the failure is before instance creation, during
bootstrap, during GitHub registration, or after job start.

### Forge EC2 Fleet Scale-Up Failures

Purpose: inspect `CreateFleet` failures by tenant, AMI, launch template, subnet,
instance type, recurrence, and error code.

Normal: empty, or rare temporary capacity errors.

Problem: repeating `InsufficientInstanceCapacity`, subnet capacity, invalid
launch template, AMI, or permission errors for one tenant or region.

Apocalypse: fleet scale-up fails across many tenants or regions.

Action: for capacity, change instance type, subnet, or AZ strategy. For AMI,
template, or IAM errors, check recent IaC and image changes.

!!! warning
This dashboard is defined in Terraform. Verify it is deployed in Splunk
before relying on it during an incident.

### Forge EC2 RunInstances Scale-Up Failures

Purpose: inspect non-fleet `RunInstances` failures, especially dedicated-host
and macOS runner paths.

Normal: empty, or isolated temporary failures.

Problem: repeated `RunInstances` errors, retry pressure, dedicated-host capacity
issues, subnet IP errors, AMI errors, or permission failures.

Apocalypse: non-fleet runner launch paths cannot create runners broadly.

Action: check AWS capacity, dedicated host allocation, AMI ownership and
sharing, subnet IP capacity, and instance profile permissions.

!!! warning
This dashboard is defined in Terraform. Verify it is deployed in Splunk
before relying on it during an incident.

### Forge ARC DIND Runner Lifecycle

Purpose: inspect ARC DIND runner scale set, init containers, hook sidecar,
runner version, and log-volume lifecycle.

Normal: hook sidecar signals and runner versions look stable. DIND categories
are not dominated by init or container failures.

Problem: init container failures, DIND errors, hook sidecar failures, log-volume
problems, or runner version drift.

Apocalypse: DIND jobs fail across tenants because Docker daemon, PVC/log
volume, or ARC lifecycle is broken.

Action: check pod events, init container logs, rootless Docker/DIND
configuration, storage/PVC, and image version.

### Forge ARC K8S Runner Lifecycle

Purpose: inspect ARC K8S-mode runner, hook sidecar, runner version, log-volume,
and job-pod PVC or scheduling lifecycle.

Normal: hook sidecar signals are stable, pod and PVC events are low, and runner
versions and log volume are current.

Problem: repeated scheduling failures, PVC stuck events, hook errors, image-pull
issues, or runner version drift.

Apocalypse: ARC K8S jobs cannot run across tenants.

Action: check Kubernetes Storage and Network, Karpenter capacity, EBS CSI, Pod
Identity, and ARC manager/listener logs.

### Forge Kubernetes Storage and Network

Purpose: inspect Kubernetes storage, EBS CSI, EKS Pod Identity, scheduling, CNI,
image pulls, Karpenter, Calico/Tigera, and EKS API errors.

Normal: scheduler, storage, and CNI warning volume is low. EBS CSI, Pod
Identity, and Calico/Tigera are healthy.

Problem: EBS provisioning waits, PVC still attached, Pod Identity failures,
Calico or Tigera issues, Karpenter errors, image-pull failures, or EKS API
authorization/storage errors.

Apocalypse: cluster-wide scheduling, CNI, or storage failures prevent ARC
workloads from running.

Action: split the issue into scheduling, storage, identity, CNI, or API auth
before changing ARC.

### Forge Lambda Operations

Purpose: inspect Forge support Lambda errors, runner-tagging failures,
trust-validator errors, and Splunk ingestion retries.

Normal: error trend is low or empty, there are no repeated ingestion retries,
and runner tagging failures are quiet.

Problem: repeated Lambda errors by function/category, new runner tagging
failures, trust validator errors, or S3 runner-log ingestion retries.

Apocalypse: multiple self-healing or ingestion Lambdas fail together.

Action: identify function and category, then inspect CloudWatch or Lambda logs
and recent deployment changes.

### Forge Trust Failures

Purpose: inspect IAM trust validation failures by validator tenant, Forge role,
tenant role, and error type.

Normal: empty, or isolated expected IAM propagation windows.

Problem: `AccessDenied`, missing trust, missing `sts:TagSession`, wrong role
ARN, SCP, or permission boundary issues for one tenant/account.

Apocalypse: broad `AssumeRole` failures across many tenants.

Action: compare tenant config, target role trust policy, role chaining, region,
session tags, SCPs, and recent IAM changes.

### Forge Runner Control Plane Health

Purpose: inspect scale-up registration, pool top-up, scale-down cleanup, GitHub
API retry, and SQS publish logs.

Normal: expected scale-up/down and top-up activity exists with few API warnings.

Problem: GitHub or SQS warnings, registration failures, cleanup failures, or
pool top-up behavior that does not match capacity settings.

Apocalypse: the control plane cannot register runners, publish work, or clean up
across tenants.

Action: map the failure to GitHub API, SQS, scale-up registration, or
scale-down cleanup.

### Forge Runner Dispatcher Rejections

Purpose: inspect workflow-job dispatcher rejects, label mismatches,
dynamic-label policy failures, and webhook dispatch errors.

Normal: zero or low expected rejections caused by tenant workflow mistakes.

Problem: rejections concentrated in one tenant, repository, or label.

Apocalypse: widespread rejections after a label contract or dispatcher change.

Action: compare requested labels to tenant runner specs, runner group
membership, and dynamic-label policy.

### Forge Stuck Workflow Job Dispatcher Health

Purpose: inspect health, alert quality, redelivery outcomes, and hot spots for
stuck `workflow_job` redelivery.

Normal: alert input quality is sane. Receiver decisions and worker outcomes are
mostly success, dedupe, or expected skip.

Problem: malformed alert payloads, repeated receiver or worker failures, one
tenant/repository hot spot, or failed delivery attempts.

Apocalypse: stuck workflow jobs accumulate while receiver or worker outcomes are
failing or absent.

Action: use this dashboard for aggregate status, then open Stuck Workflow Job
Dispatcher Debug for per-key lifecycle and raw samples.

### Forge Stuck Workflow Job Dispatcher Debug

Purpose: inspect per-key lifecycle, runner capacity decisions, delivery
attempts, and raw samples for stuck workflow redelivery.

Normal: lifecycle shows alert receive, decision, worker processing, GitHub
delivery attempt, and no terminal error.

Problem: a missing stage, skipped key, delivery failure, capacity decision
mismatch, or bad input payload.

Apocalypse: many per-key lifecycles fail at the same stage.

Action: inspect the exact workflow job key, GitHub delivery ID, tenant,
repository, and runner group.

## Metrics Dashboards

### Forge Impact

Purpose: adoption, usage, active runners, and runner-minutes by EC2/K8S and
tenant.

Use for platform usage, capacity planning, and maintenance partner
conversations. Do not use it as the first root-cause dashboard during an
incident.

### Runner EC2

Purpose: host-level EC2 runner CPU, memory, disk, network, active hosts, OTel
agent, and EC2 status checks.

Use with Forge EC2 Runner Lifecycle and Forge Runner Capacity.

Problem signs: high CPU, disk, memory, network errors, OTel host loss, or EC2
status check failures.

### Runner K8S

Purpose: Kubernetes pod availability, CPU/memory, network, pod phase, container
restarts, and Splunk OTel collector health.

Use with ARC lifecycle dashboards and Forge Kubernetes Storage and Network.

Problem signs: pending pods, restarts, high memory/CPU, network errors, or
collector degradation.

### Lambda

Purpose: Lambda invocations, errors, throttles, duration, provisioned
concurrency, and spillover.

Use with Forge Lambda Operations.

Problem signs: errors, throttles, duration spikes, or spillover for Forge
support Lambdas.

### SQS

Purpose: queue message state, oldest message age, sent/received/deleted counts,
empty receives, and DLQ backlog.

Use with Webhook Job Log Pipeline, stuck dispatcher, trust validator, and DLQ
redrive investigations.

Problem signs: visible backlog grows, oldest age rises, or DLQ visible messages
appear.

### DynamoDB

Purpose: throttles, request latency, consumed capacity, returned item count, and
user/system errors.

Use with stuck dispatcher and global-lock/control-plane investigations.

Problem signs: throttles, HTTP 500s, high latency, or capacity pressure for
lock/dedupe tables.

### EBS

Purpose: EBS volume utilization, latency, queue length, throughput, I/O, and
state.

Use with Kubernetes Storage and Network and EC2 Runner Lifecycle.

Problem signs: high latency, high queue length, low idle time, or abnormal
volume state.

### Billing

Purpose: AWS cost by service and tenant from billing exports.

Use for cost review and anomaly investigation, not acute availability triage.

Problem signs: one tenant or service spikes unexpectedly, tags are missing, or
billing export freshness changes.

### OpenCost

Purpose: Kubernetes tenant CPU/memory allocation cost, monthly run rate, trends,
and top pod cost.

Use with Forge Impact and Runner K8S.

Problem signs: runaway namespace/pod cost, missing tenant dimensions, or sudden
allocation spike.

## Follow-Up Searches

Use these as starting points in Splunk Cloud.

```spl
index="forge-prod-index"
| stats count as events dc(source) as sources dc(forgecicd_tenant) as tenants latest(_time) as last_time by sourcetype
| eval last_seen=strftime(last_time, "%Y-%m-%d %H:%M:%S")
| sort - events
```

```spl
index="forge-prod-index" sourcetype="forgecicd:runner-logs:json"
| spath path=workflow_job.created_at output=created_at
| spath path=workflow_job.started_at output=started_at
| spath path=workflow_job.runner_group_name output=runner_group
| rex field=source "^(?<source_tenant>[a-z0-9]+)-"
| eval tenant=coalesce(forgecicd_tenant, source_tenant)
| eval queue_sec=strptime(started_at,"%Y-%m-%dT%H:%M:%SZ")-strptime(created_at,"%Y-%m-%dT%H:%M:%SZ")
| eval queue_ge_10m=if(queue_sec>=600,1,0)
| stats count as jobs sum(queue_ge_10m) as queue_ge_10m p95(eval(if(queue_sec>=0, queue_sec, null()))) as p95_queue_sec by tenant runner_group
| sort - queue_ge_10m - p95_queue_sec
```

```spl
index="forge-prod-index" forgecicd_log_type="webhook" "Github event"
| spath path=github.github-event output=github_event
| spath path=github.repository output=repository
| spath path=github.status output=status
| spath path=github.conclusion output=conclusion
| where github_event="workflow_job"
| stats count as events count(eval(status="queued")) as queued count(eval(status="completed")) as completed count(eval(conclusion="failure")) as failures by forgecicd_tenant repository
| sort - queued - failures
```

## Improvement Backlog

P0:

- Verify deployment of `forge_ec2_fleet_scale_up_failures`.
- Verify deployment of `forge_ec2_run_instances_scale_up_failures`.
- Add owner/contact metadata to every dashboard.

P1:

- Add a short markdown help panel to every dashboard.
- Standardize dashboard descriptions instead of leaving wrapper descriptions
  empty.
- Add drilldowns from summary dashboards to narrow dashboards with tenant,
  repository, and time tokens.
- Add explicit color rules for queue over 10 minutes, jobs queued over 15
  minutes, stale sourcetypes, DLQ backlog, Lambda errors, and trust failures.

P2:

- Split Forge Troubleshooting into guided tabs if it becomes too dense.
- Add source-code and runbook references to dashboards.
- Review SPL cost for high-volume searches.
- Add known-good and known-bad examples for common incidents.
