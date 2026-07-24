# Splunk Observability Dashboard Runbook

Use this runbook to triage Forge availability, dependency health, capacity,
resource pressure, and cost in Splunk Observability Cloud. The exact chart
inventory is in the
[Splunk Observability Dashboard Panel Reference](splunk-o11y-dashboard-panel-reference.md).

Splunk Observability shows metric state. Use the
[Splunk Cloud Dashboard Runbook](splunk-dashboard-runbook.md) to explain the
event sequence and retrieve error details.

## Triage Sequence

1. Confirm the selected time window and dashboard variables.
1. Prove that the expected telemetry source is fresh.
1. Open `Forge Tenant Impact` to identify the affected tenant and subsystem.
1. Open the narrow resource or dependency dashboard.
1. Record the tenant, region, cluster, and affected resource dimensions.
1. Correlate the same window in Splunk Cloud logs and the source platform.

Do not treat an empty chart as healthy until freshness is established.

## Severity Language

| State      | Meaning                                                                                                                                                |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Normal     | Expected telemetry is fresh, errors and pressure are absent or isolated, and workload demand is being served.                                          |
| Warning    | Telemetry is degraded, a threshold is approaching, or one resource shows a short-lived symptom without confirmed tenant impact.                        |
| Problem    | One tenant, region, cluster, or subsystem has sustained failures, backlog, resource pressure, or missing required telemetry.                           |
| Apocalypse | Multiple tenants, regions, runner modes, or control-plane dependencies fail together, or telemetry disappears broadly enough that operators are blind. |

## Which Dashboard First

| Symptom                                                             | Start here                                    | Then open                                                               |
| ------------------------------------------------------------------- | --------------------------------------------- | ----------------------------------------------------------------------- |
| The symptom is unclear.                                             | Forge Tenant Impact                           | The highest-ranked subsystem dashboard                                  |
| GitHub authentication, runner API, or rate limits are suspected.    | Forge External Dependency Health              | Splunk Cloud control-plane logs and the regional monitor Lambda logs    |
| EC2 runners are slow, unhealthy, or missing telemetry.              | Forge Tenant - EC2 Runners                    | Forge EC2 Runner Lifecycle and Forge Runner Capacity in Splunk Cloud    |
| ARC tenant pods are pending, restarting, or resource constrained.   | Forge Tenant - K8S Runners                    | Forge Control Plane - Kubernetes and ARC lifecycle logs                 |
| Several ARC tenants fail in one cluster.                            | Forge Control Plane - Kubernetes              | Kubernetes Storage and Network in Splunk Cloud                          |
| Lambdas fail, throttle, or become slow.                             | Forge Tenant - Lambdas                        | Forge Lambda Operations in Splunk Cloud                                 |
| Shared Lambdas fail, throttle, or become slow.                      | Forge Control Plane - Lambdas                 | Matching regional control-plane Lambda logs                             |
| Shared Kinesis streams throttle, lag, or become slow.               | Forge Control Plane - Kinesis                 | Kinesis producers, consumers, and matching Lambda/Firehose logs         |
| Work accumulates or enters a DLQ.                                   | Forge Tenant - SQS                            | Webhook pipeline, dispatcher, redrive, or control-plane logs            |
| Shared work accumulates or enters a DLQ.                            | Forge Control Plane - SQS                     | Matching regional control-plane queue producer and consumer logs        |
| Tenant or shared S3 storage grows unexpectedly.                     | Forge Tenant - S3 or Forge Control Plane - S3 | Bucket lifecycle, retention, and producer logs                          |
| An AWS service approaches its configured account or regional limit. | Forge Control Plane - AWS Service Limits      | AWS Trusted Advisor, Service Quotas, and the service-specific dashboard |
| Regional Lambda throttling or queued-build saturation is suspected. | Forge AWS Regional Platform Health            | Tenant Lambda/SQS dashboards and matching regional control-plane logs   |
| Lock, dedupe, or support-table operations fail.                     | Forge Tenant - DynamoDB                       | The Lambda and SQS dashboards, then matching logs                       |
| Runners or pods show storage pressure.                              | Forge Tenant - EBS                            | EC2 lifecycle or Kubernetes storage logs                                |
| Runner adoption or runtime is the question.                         | Forge Runner Usage                            | EC2 or K8S runner dashboard                                             |
| AWS invoice cost is the question.                                   | Forge Billing and Cost - AWS                  | Billing export and tenant-tag validation                                |
| Kubernetes allocation cost is the question.                         | Forge Billing and Cost - OpenCost             | Runner K8S and cluster allocation metrics                               |

## Freshness Before Severity

Use the failure pattern to identify the telemetry boundary:

| Missing data pattern                                     | Likely boundary                                                              | Check                                                                                                 |
| -------------------------------------------------------- | ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| All O11y dashboards are empty.                           | Splunk access, organization, dashboard variables, or broad ingestion failure | SignalFx realm/API configuration, team access, selected time range, and active integrations           |
| AWS dashboards are empty but Kubernetes charts work.     | Splunk AWS integration or AWS metric scope                                   | AWS integration status, account/region filters, namespaces, and tenant tags                           |
| Kubernetes dashboards are empty but AWS charts work.     | Splunk OTel Collector or configured cluster scope                            | Collector pods, exporter queue, refused points, and `k8s.cluster.name` suggestions                    |
| Host-level EC2 charts are empty but AWS EC2 charts work. | Host collector missing from runners                                          | `Active hosts missing Splunk OTel agent`, runner image, and collector service                         |
| Dependency charts are empty.                             | Regional monitor schedule or direct ingest                                   | Lambda invocation, O11y ingest token, metrics endpoint, tenant config, and `Regional probe execution` |
| AWS regional platform health alone is empty.             | Dashboard allow-list or required CloudWatch metric dimension                 | `aws_account_id`, `aws_region`, `aws_tag_ProductFamilyName`, and Splunk AWS integration coverage      |
| AWS billing alone is empty.                              | Billing export or billing metric publisher                                   | Export freshness, publisher execution, and `forgecicd_tenant` dimensions                              |
| OpenCost alone is empty.                                 | OpenCost scrape/export or cluster scope                                      | OpenCost pods, Prometheus scrape, node price metrics, and configured clusters                         |
| One tenant is empty everywhere.                          | Tenant selector, tag, namespace, or deployment gap                           | Tenant spelling, `aws_tag_TenantName`, Kubernetes namespace, region, and active workload              |

## Dashboard Procedures

### Forge Tenant Impact

Purpose: rank current cross-service symptoms by tenant before resource-level
investigation.

Normal: failure leaderboards are empty or low, and resource-pressure rankings
match known workload bursts.

Problem: one tenant dominates Lambda errors, EC2 pressure, pending or failed
pods, SQS backlog, EBS queueing, or EC2 status failures.

Apocalypse: several failure categories affect multiple tenants or regions at
the same time.

Action: select the tenant and region, note the highest-ranked category, and
open that subsystem's dashboard. Do not use rankings alone as a health
percentage; they show relative impact.

### Forge Runner Usage

Purpose: measure runner adoption, active capacity, distinct runners, and
runner-minutes by runtime and tenant.

Normal: runner counts and minutes follow known job demand and tenant rollout.

Problem: an unexpected runtime shift, a tenant with zero usage despite known
demand, or a sharp capacity change without a planned deployment.

Action: compare the selected window with GitHub job demand. Use the EC2 or K8S
runner dashboard for health. This dashboard is not an incident severity score.

### Forge Tenant - EC2 Runners

Purpose: inspect AWS EC2 and host-level telemetry for runner CPU, memory, disk,
network, status checks, capacity distribution, and OTel agent coverage.

Normal: status checks are zero, memory and filesystem headroom exist, network
errors and swapping are low, and active AWS hosts also emit host telemetry.

Problem: sustained CPU or memory pressure, high filesystem utilization,
swapping, network errors, EC2 status failures, or active hosts listed as
missing the OTel agent.

Apocalypse: status checks, telemetry loss, or resource exhaustion affect many
tenants or availability zones.

Action: capture tenant, instance ID, image ID, instance type, availability
zone, and time window. For a missing agent, check the runner image and agent
service before treating host charts as proof the instance is idle. Correlate
with EC2 lifecycle and capacity logs.

### Forge Tenant - K8S Runners

Purpose: inspect tenant ARC runner pods, deployment availability, pod phases,
CPU, memory, network, restarts, and termination reasons.

Normal: desired and available pods converge, running pods follow demand,
pending/failed/unknown phases remain low, and restarts do not grow repeatedly.

Problem: desired capacity exceeds available capacity, pods stay pending,
containers restart, memory approaches limits, or network errors increase.

Apocalypse: tenant runner pods fail across several namespaces or clusters.

Action: capture cluster, namespace, pod, node, phase, and termination reason.
If several tenants share the symptom, move to `Forge Control Plane - Kubernetes`. Otherwise correlate with the tenant ARC lifecycle logs.

### Forge Control Plane - Kubernetes

Purpose: separate shared cluster and telemetry health from tenant runner
workload health.

Normal: platform and collector pods run, node pressure conditions are clear,
the exporter queue has headroom, and refused or failed metric points remain
zero.

Problem: platform or collector pods are pending/failed, one node reports
pressure, exporter utilization grows, or metric points are refused.

Apocalypse: cluster-wide scheduling, networking, telemetry, or platform pod
failure affects multiple tenants.

Action: identify the cluster, namespace, pod, node, and pressure condition.
For exporter saturation, restore the downstream path before diagnosing
no-data charts. For platform failure, use Kubernetes events and the Splunk
Cloud storage/network dashboard.

### Forge Tenant - Lambdas

Purpose: inspect invocation volume, errors, throttles, duration, tenant impact,
and version-level behavior.

Normal: errors and throttles are zero or isolated, duration follows the
function baseline, and expected versions receive traffic.

Problem: one tenant, function, or version has sustained errors, throttling, or
duration growth.

Apocalypse: several Forge control-plane Lambdas fail or throttle across
tenants.

Action: capture tenant, function name, function version, region, and first
failing window. Use Splunk Cloud or CloudWatch logs to retrieve the exception
and request context.

### Forge Control Plane - Lambdas

Purpose: inspect shared Forge Lambda functions that are not tagged to a tenant.

Normal: expected functions report invocations; errors and throttles are zero or
isolated; duration follows each function's baseline.

Problem: a function has sustained errors, throttling, unexpected inactivity, or
duration growth.

Action: confirm the account, region, and product-family scope; identify the
function; correlate errors, throttles, and duration; then inspect its regional
Lambda logs. If the dashboard is unexpectedly empty, verify the AWS resource
tags and the `aws_tag_TenantName` dimension exported by the Splunk AWS
integration.

### Forge Control Plane - Kinesis

Purpose: inspect shared Forge Kinesis streams that are not tagged to a tenant.

Normal: read/write throttling is zero, iterator age remains near the consumer
baseline, successful operations continue, and latency follows the stream's
normal pattern.

Problem: throughput-exceeded counters rise, iterator age grows, successful
operations stop unexpectedly, or producer/consumer latency increases.

Action: confirm the account, region, and product-family scope; identify the
stream; compare incoming volume with successful operations; then inspect the
producer, consumer, Lambda, or Firehose logs. Iterator age is milliseconds and
represents consumer lag; correlate it with expected traffic before assigning
severity.

### Forge Tenant - SQS

Purpose: inspect message flow, visible and in-flight work, oldest-message age,
consumer behavior, and DLQs.

Normal: sent, received, and deleted trends remain proportionate; visible
backlog drains; DLQ charts are empty.

Problem: visible backlog or oldest-message age rises, deletes lag receives,
empty receives are unexpectedly high, or a DLQ contains messages.

Apocalypse: several control-plane queues stop draining or multiple tenant DLQs
grow together.

Action: capture tenant, queue name, region, oldest age, and backlog. Identify
the queue's consumer Lambda, then check its errors, concurrency, event-source
mapping, and partial-batch retry behavior.

### Forge Control Plane - SQS

Purpose: inspect shared Forge queues that are not tagged to a tenant.

Normal: visible backlog and oldest-message age remain low, message operations
remain proportionate, and DLQ panels are empty.

Problem: shared work stops draining, sent/received/deleted operations diverge,
or a control-plane DLQ contains messages.

Action: confirm the account, region, and product-family scope; identify the
queue and consumer; inspect delayed and in-flight state; then correlate the
producer, consumer, and redrive logs. The DLQ panels recognize `dead-letter`,
`dead_letter`, `dlq`, and `DLQ` naming patterns.

### Forge Tenant - S3

Purpose: inspect daily storage size and object inventory for tenant-tagged
Forge S3 buckets.

Normal: expected GitHub-log and tenant support buckets report once per day;
size and object-count growth follows retention and workload baselines.

Problem: a bucket stops reporting for more than two days, grows unexpectedly,
or shows a storage-class distribution inconsistent with its lifecycle policy.

Action: confirm account, region, product-family, and tenant scope; identify the
bucket; then inspect its lifecycle/retention configuration and producer logs.
This dashboard does not imply S3 request health because request metrics are not
currently present for Forge buckets.

### Forge Control Plane - S3

Purpose: inspect daily storage inventory for shared Forge buckets without the
`TenantName` tag.

Normal: state, artifact, billing, and delivery buckets follow their expected
retention and growth patterns.

Problem: a shared bucket stops reporting, grows unexpectedly, or accumulates
objects beyond its operational retention expectation.

Action: identify the bucket and owning pipeline, verify lifecycle rules, then
correlate with billing, state, artifact, or Splunk delivery logs as appropriate.

### Forge Control Plane - AWS Service Limits

Purpose: review AWS Trusted Advisor service-limit usage for supported AWS
services used by Forge.

Normal: every limit remains below 80% usage.

Problem: a limit reaches 80% or higher. A value at or above 100% is critical.

Action: confirm the AWS account and Trusted Advisor `Region`, identify the
`ServiceLimit`, then check AWS Service Quotas and Trusted Advisor. Decide
whether to request an increase or reduce the resource count before the limit
blocks Forge deployment or scaling. IAM limits use the global `Region` value
`-`, which the dashboard includes automatically.

### Forge Tenant - DynamoDB

Purpose: inspect support-table capacity, throttling, errors, item volume, and
request latency.

Normal: throttles and system errors are zero, latency follows the table
baseline, and provisioned capacity has headroom.

Problem: read/write throttle events, sustained consumed-capacity pressure,
system errors, or latency growth for a control-plane table.

Apocalypse: shared lock, dedupe, or coordination tables fail across tenants.

Action: capture table, operation, tenant dimension when present, region, and
time window. Correlate with the calling Lambda and SQS backlog. Do not assign
tenant ownership when the live table metric lacks a confirmed tenant
dimension.

### Forge Tenant - EBS

Purpose: inspect EBS throughput, operations, latency, queueing, idle time,
state, and exceeded IOPS limits.

Normal: queue length and latency remain low, idle time exists, volume state is
expected, and IOPS-exceeded signals remain zero.

Problem: queue length and latency rise together, idle time collapses, or a
volume reports an exceeded IOPS allowance.

Apocalypse: storage saturation or volume failure affects several runner hosts
or Kubernetes nodes.

Action: capture tenant, volume ID, region, and attached instance or node. Check
volume type, provisioned IOPS/throughput, filesystem pressure, and the
workload's I/O pattern.

### Forge Billing and Cost - AWS

Purpose: inspect gross and net AWS billing data by service and tenant.

Normal: cost movement matches runner demand and planned infrastructure.

Problem: a tenant/service combination spikes unexpectedly, tenant tags are
missing, or billing telemetry goes stale.

Action: confirm billing data freshness before comparing short windows. Validate
cost-allocation tags and use the AWS bill for authoritative charges.

### Forge Billing and Cost - OpenCost

Purpose: estimate Kubernetes CPU and memory allocation cost by namespace, pod,
and cluster.

Normal: allocation cost follows runner demand and expected node pricing.

Problem: one namespace or pod has an unexplained allocation spike, node prices
are missing, or current cost diverges sharply from the workload.

Action: capture cluster, namespace, pod, CPU allocation, and memory allocation.
Compare resource requests and limits with actual runner demand. OpenCost is an
allocation estimate, not an AWS invoice.

### Forge AWS Regional Platform Health

Purpose: detect regional Forge control-plane saturation before it becomes a
multi-tenant runner outage.

Normal: queued-build oldest age remains below `60s`, visible backlog drains,
queued-build DLQ sends remain zero, and Lambda throttle rate follows the known
regional baseline.

Problem: oldest age exceeds `75s` together with more than `10` visible messages
for `10m`, or a region's Lambda throttle rate rises materially above its known
baseline.

Apocalypse: oldest age exceeds `300s` for `10m`, queued-build messages enter a
DLQ, or several regions show sustained queue and Lambda pressure with confirmed
tenant impact.

Action:

1. Filter by `aws_account_id`, `aws_region`, and
   `aws_tag_ProductFamilyName`.
1. Correlate oldest age with visible backlog; neither alone proves consumer
   failure.
1. Open `Forge Tenant - SQS` to identify affected queues and
   `Forge Tenant - Lambdas` to identify throttled consumers.
1. For DLQ activity, inspect the failed message and consumer logs before
   replaying it.
1. Treat Lambda throttle count as supporting evidence only. The observed
   throttle-rate warning baselines are `use1 0.5%`, `usw2 20%`, and `euw1 65%`
   sustained for `10m`; validate those baselines before introducing paging.
1. Confirm recovery only after oldest age remains below `60s` for `15m` and
   backlog is draining.

Terraform ownership:

- Dashboard:
  `modules/integrations/splunk_o11y_conf_shared/dashboards/aws_regional_health`
- Detectors:
  `modules/integrations/splunk_o11y_conf_shared/detectors/aws_regional_health`
- Configuration:
  `dashboard_variables.aws_regional_health.dynamic_variables`

Keep the manual dashboard `HN_5cVmAgAA` until the managed dashboard is deployed
and all five panels, selectors, detector rules, and notification routes have
been verified. Remove the manual dashboard only after comparing both
dashboards over the same production time window.

### Forge External Dependency Health

Purpose: verify, from every deployed Forge region, the tenant-specific AWS SSM
configuration and configured GitHub API path.

Normal: GitHub and SSM availability equal `1`, probe execution remains fresh,
latency follows baseline, and the GitHub rate-limit budget remains comfortably
above the configured detector threshold.

Problem: one tenant/region reports availability `0`, stops emitting probe
cycles, shows sustained latency, or approaches the GitHub API limit.

Apocalypse: probes fail across many tenants or regions, or the configured
GitHub service is broadly unavailable.

Action:

1. Filter by `TenantName` and `AWSRegion`.
1. Identify `Provider` and `CheckName`.
1. For SSM failure, verify the regional tenant prefix and required parameters.
1. For GitHub failure, verify App authentication, installation, organization,
   GHES URL, and the organization runners API.
1. For no data, inspect the regional monitor Lambda schedule, invocation logs,
   O11y ingest token, and metrics endpoint.
1. For low rate limit, reduce avoidable API traffic and inspect the
   installation's rate-limit reset before probes begin failing.

The regional SSM check reads these parameters under
`/forge/<deployment_prefix>`:

- `github_app_key`
- `github_app_client_id`
- `github_app_id`
- `github_app_installation_id`
- `github_ghes_url`
- `github_ghes_org` for regional discovery

## Detector Reference

### Kubernetes Detectors

Kubernetes detectors are always created and are scoped to configured Forge
clusters. Empty cluster suggestions intentionally produce no matching cluster
rather than a platform-wide detector.

| Detector/rule                               | Default trigger                                                       | Severity |
| ------------------------------------------- | --------------------------------------------------------------------- | -------- |
| K8S OTel no data                            | Pod-phase telemetry remains absent for `10m` after a `4h` fill window | Warning  |
| No running Splunk OTel collector pods       | Running collectors remain below `1` for `10m`                         | Major    |
| Splunk OTel collector pod pending           | A collector remains pending for `5m`                                  | Warning  |
| Splunk OTel collector pod failed or unknown | A collector remains failed/unknown for `5m`                           | Major    |
| Splunk OTel collector container restarting  | Restart delta exceeds `0` in the `10m` evaluation window              | Warning  |
| K8S tenant pods pending                     | Pending tenant pods exceed `0` for `10m`                              | Warning  |
| K8S platform pods unhealthy                 | Failed/unknown platform pods exceed `0` for `5m`                      | Major    |

The defaults come from `k8s_detector_config` and
`k8s_otel_collector_config`.

### Dependency Detectors

Dependency detectors are always enabled. The module creates one detector per
configured dependency-probe tenant using the fixed defaults below.

| Rule                                          | Default trigger                                 | Severity |
| --------------------------------------------- | ----------------------------------------------- | -------- |
| Tenant dependency probe has no data           | Probe execution remains absent for `15m`        | Warning  |
| Tenant GitHub App SSM credentials unavailable | SSM availability remains below `1` for `10m`    | Major    |
| Tenant GitHub API unavailable                 | GitHub availability remains below `1` for `10m` | Major    |
| Tenant GitHub API rate-limit budget low       | Remaining budget stays below `10%` for `10m`    | Warning  |

Each dependency signal retains `AWSRegion`, so the alert
identifies the affected regional deployment.

### AWS Regional Platform Detector

The regional platform detector is always enabled for the account, region, and
product-family values configured under
`dashboard_variables.aws_regional_health.dynamic_variables`.

| Rule                         | Trigger                                                               | Severity |
| ---------------------------- | --------------------------------------------------------------------- | -------- |
| Build queue oldest age major | Oldest queued-build age stays above `300s` for `10m`                  | Major    |
| Build queue backlog warning  | Oldest age stays above `75s` and visible backlog above `10` for `10m` | Warning  |
| Queued-build DLQ activity    | At least one message is sent to a queued-build DLQ in five minutes    | Major    |

Lambda throttle panels are diagnostic-only. Their regional baselines are not
encoded as detector rules, and throttle count does not alert independently.

## Notification Routing

- `detector_notifications = null` routes detector rules to `Team,<team>`.
- An explicit list routes rules to those Splunk Observability destinations.
- `detector_notifications = []` creates detectors without notifications.
- `detector_name_prefix` controls the common detector name prefix.

Verify notification delivery after changing a destination. A detector existing
in Terraform does not prove the downstream paging integration is working.

## Escalation Evidence

Record:

- incident start and selected dashboard window;
- tenant, AWS region, region alias, and Kubernetes cluster;
- dashboard, chart, metric, and detector rule;
- function, queue, table, volume, instance, namespace, pod, or node identity;
- whether adjacent telemetry sources are fresh;
- first abnormal value and whether it is sustained;
- matching Splunk Cloud log evidence;
- recent Forge, tenant, runner-image, collector, or integration deployment;
- actions already attempted and their result.

Avoid screenshots without filters, legends, time window, and resource
dimensions. Those details are needed to reproduce the query.
