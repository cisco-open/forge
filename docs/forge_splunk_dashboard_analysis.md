# Forge Splunk dashboard analysis

Scope used for the expanded analysis:

```spl
index="srea-forge-prod-index" earliest=-30d latest=now
```

Dashboard defaults should stay at `-24h@h,now` for performance. Use the time picker for `-30d@d,now` when doing deeper investigations.

## Prompt to reuse

Use this prompt when you want the same analysis refreshed:

```text
Analyze Forge production logs in Splunk for the last 30 days.

Use index=srea-forge-prod-index earliest=-30d latest=now.

Read the Forge codebase first, especially:
- modules/integrations/splunk_cloud_conf_shared props/transforms and dashboards
- modules/core/arc and modules/platform/arc_deployment
- modules/platform/forge_runners and modules/platform/ec2_deployment
- modules/platform/forge_runners/github_actions_job_logs
- modules/platform/forge_runners/redrive_deadletter
- modules/integrations/splunk_cloud_s3_runner_logs and splunk_otel_eks

Also use upstream behavior from:
- actions/actions-runner-controller runner scale sets, listener/manager logs, EphemeralRunnerSet, DIND, hooks, PVCs, network startup, and delayed allocation troubleshooting
- github-aws-runners/terraform-aws-github-runner v7.7.1 multi-runner EC2 lifecycle, webhook/EventBridge/SQS/DLQ, scale-up/scale-down Lambda, ephemeral runners, runner log files, runner hooks, SSM, AMI, and scale_errors

Find patterns that explain production troubleshooting for all Forge log types:
- GitHub workflow job failures, queue time, duration, negative/missing timestamp data, runner families, tenants, repos, runner groups, and runner names
- ARC manager/listener capacity, pending/running/failed/deleting runner counts, scale set names, runner versions, DIND/init container failures, hook sidecar health, PVC/EBS events, scheduler/Karpenter placement, CNI, image pulls, and EKS API audit errors
- EC2 runner lifecycle through webhook, SQS queue, scale Lambda, EC2 instance boot/user-data, CloudWatch agent, hook logs, runner diagnostics, SSM/AMI updates, instance tagging, scale_errors/capacity errors, spot/on-demand, and DLQ redrive
- Lambda categories for ec2-update-runner-tags, ec2-update-runner-ssm-ami, forge-trust-validator, job-log-dispatcher, job-log-archiver, redrive-deadletter, webhook, register-github-app-runner-group, and Splunk S3 runner-log ingestion
- IAM trust validation failures by validator tenant and role ARN
- Splunk ingestion quality: object_complete, kinesis retries/failures, JSON failures, tag fetch failures, unsupported object skips, line-too-large skips, missing extracted fields, sourcetype/source inventory

Return:
1. the strongest 30-day findings with counts;
2. SPL searches that support each finding;
3. dashboard recommendations grouped by operator workflow;
4. any extraction gaps or telemetry quality issues that hide root cause.
```

## 30-day findings

The 30-day inventory shows a very large index. Top sourcetypes:

| Sourcetype                           |      Events |
| ------------------------------------ | ----------: |
| `forgecicd:runner-logs:logs`         | 883,023,701 |
| `kube:container:runner`              | 442,178,714 |
| `aws:cloudwatchlogs:forgecicd`       | 197,672,390 |
| `aws:cloudwatchlogs`                 | 100,713,716 |
| `kube:container:runner-logs`         |  48,684,139 |
| `kube:container:init-dind-externals` |  21,552,375 |
| `kube:container:listener`            |   5,093,319 |
| `kube:container:manager`             |   2,727,464 |
| `kube:events`                        |     909,824 |
| `forgecicd:runner-logs:json`         |     315,517 |
| `kube:container:dind`                |     250,460 |
| `kube:container:hook`                |      64,921 |

GitHub job JSON over 30 days:

- `forgecicd:runner-logs:json` has 285,068 successes and 30,473 failures.
- `netsectest` has the strongest failure-rate signal: 14,491 jobs on runner names matching `GitHub Actions`, 11,552 failures, 79.72% failure rate.
- `isovalent` dominates volume: 142,002 jobs / 7,336 failures on `GitHub Actions` style names, plus 60,667 jobs / 5,555 failures on Forge runner names.
- Queue pressure is real for Forge runner names: `isovalent` p95 queue was 797s with 4,144 jobs queued at least 10 minutes.
- Long-tail runner names have extreme p95 queue values and should be treated carefully because some records have negative queue times.
- Negative queue time exists in job JSON and should be tracked as telemetry quality, not capacity.

Lambda/support findings:

- `ec2-update-runner-tags` is the dominant error source.
- Top 30-day `runner_name missing` counts: `isovalent` 306,090, `netsectest` 85,380, `duofederal` 68,692, `cnhe` 33,531, `tdrdp` 23,105, `redis` 21,378.
- Top `InvalidInstanceID.NotFound`: `isovalent` 147,675 and `cnhe` 112,978.
- Trust validator AccessDenied is high for `acgw`, `sniproxy`, `ssesre`, `malgudi`, `frouter`, `pinacl`, `cspeec`, `cspeucb`, `csdevops`, and `releng`.
- Trust validator `tag session` failures are broad and recurring; many logs do not include a clean role ARN, so the dashboard needs both summary counts and raw sample panels.

Kubernetes/ARC findings:

- `kube:events` is storage and scheduling heavy: about 146,992 PVC/volume attach events, 126,999 EBS provisioning wait/fail events, 34,519 scheduler capacity/affinity events, and 2,705 CNI/network-not-ready events.
- ARC manager `Ephemeral runner counts` show pending spikes without failed runner count spikes:
  - `csdevops/k8s-4z996`: max pending 91
  - `srea/k8s-2zt95`: max pending 86
  - `srea/k8s-p9rkl`: max pending 52
  - `srea/k8s-p6vtw`: max pending 42
  - `redis/k8s-89tl6`: max pending 41
  - `tdrdp/k8s-7dn5r`: max pending 38
  - `cscore/k8s-6phcg`: max pending 35
  - `frouter/k8s-szf6x`: max pending 28
- Forge ARC code uses `gha-runner-scale-set` chart `0.14.2`, Kubernetes and DIND modes, job hooks, hook sidecars, runner-log sidecars, tenant taints/affinity, `karpenter.sh/do-not-disrupt`, and per-runner PVCs. The dashboard should isolate DIND/init/PVC/Karpenter signals from job log text.

EC2 runner and job-log pipeline findings:

- Forge vendors `github-aws-runners/terraform-aws-github-runner` v7.7.1 and enables EventBridge, redrive build queues, ephemeral runners, SSM, detailed monitoring, custom runner hooks, and CloudWatch runner log files.
- Job-log dispatcher has high healthy enqueue volume: `isovalent` 259,056, `netsectest` 24,021, `cnhe` 17,145, `duofederal` 14,957, `srea` 11,385, `redis` 10,661.
- Job-log archiver has actionable error categories: `isovalent` archiver errors 444, `cspeucb` missing IDs 226, plus smaller job-log-not-found and invalid-json counts.
- Redrive-deadletter logs are present for most tenants around the same event counts, so DLQ redrive should be visible as its own panel.
- Splunk S3 runner-log ingestion completed many objects but has quality defects: `object_complete` 509,246 in us-east-1, 82,913 in us-west-2, 38,961 in eu-west-1; us-east-1 also had 378 AccessDenied, 278 Kinesis retries, 189 JSON object failures, 29 line-too-large skips, and 11 Kinesis failures after retries.

EKS API audit findings:

- Kube API audit has repeated 404 `get leases` across all prod clusters at about 1.82M per cluster in 30 days.
- Repeated 403 `get leases` occurs in `eks-node-operator`, `eks-network-operator`, and `eks-storage-operator`.
- ARC-related 404s appear for pods, secrets, PVCs, and `ephemeralrunners` patch operations in tenant namespaces.

## Dashboard set

Dashboards added or updated in `modules/integrations/splunk_cloud_conf_shared`:

- `forge_troubleshooting`: broad top-level troubleshooting console.
- `forge_runner_capacity`: GitHub queue pressure plus ARC runner set state.
- `forge_lambda_operations`: Lambda error categories, runner tagging, ingestion retries, and samples.
- `forge_k8s_storage_network`: PVC/EBS/scheduler/CNI/API-audit storage and controller errors.
- `forge_trust_failures`: trust validator role and AccessDenied detail.
- `forge_ingestion_quality`: sourcetype/source inventory, missing fields, runner-log ingestion quality.
- `forge_arc_dind_health`: ARC DIND, init containers, hook sidecars, runner versions, PVC/Karpenter signals.
- `forge_ec2_runner_lifecycle`: EC2 webhook/scale/AMI/SSM/user-data/hook lifecycle.
- `forge_webhook_joblog_pipeline`: GitHub webhook to dispatcher, SQS/DLQ, archiver, S3/Splunk ingestion path.

## SPL building blocks

30-day sourcetype inventory:

```spl
| tstats count where index="srea-forge-prod-index" by sourcetype
| sort - count
```

ARC runner scale set state:

```spl
search index="srea-forge-prod-index" sourcetype="kube:container:manager" "Ephemeral runner counts"
| rex field=_raw "\"namespace\":\"(?<namespace>[^\"]+)\""
| rex field=_raw "\"name\":\"(?<scale_set>[^\"]+)\""
| rex field=_raw "\"pending\": (?<pending>[0-9]+)"
| rex field=_raw "\"running\": (?<running>[0-9]+)"
| rex field=_raw "\"failed\": (?<failed>[0-9]+)"
| rex field=_raw "\"deleting\": (?<deleting>[0-9]+)"
| eval tenant=coalesce(forgecicd_tenant,namespace)
| stats max(pending) as max_pending avg(pending) as avg_pending max(running) as max_running max(failed) as max_failed max(deleting) as max_deleting count as samples latest(_time) as latest by tenant scale_set
| eval avg_pending=round(avg_pending,2)
| sort - max_pending - max_failed
```

Kubernetes storage/scheduler categories:

```spl
search index="srea-forge-prod-index" sourcetype="kube:events"
| eval class=case(
    match(_raw,"Multi-Attach|still attached|VolumeAttachment|volume node affinity"),"pvc/volume attach",
    match(_raw,"Waiting for a volume to be created|provision|ProvisioningFailed|failed to provision"),"ebs provision wait/fail",
    match(_raw,"Insufficient cpu|Insufficient memory|didn.t match Pod.s node affinity|0/[0-9]+ nodes are available"),"scheduler capacity/affinity",
    match(_raw,"cni|network plugin is not ready|NetworkPluginNotReady"),"cni/network not ready",
    match(_raw,"ImagePullBackOff|ErrImagePull|Back-off pulling image"),"image pull",
    true(),"other")
| stats count as events dc(host) as hosts latest(_time) as latest by class
| sort - events
```

Lambda issue categories:

```spl
search index="srea-forge-prod-index" (sourcetype="aws:cloudwatchlogs:forgecicd" OR sourcetype="aws:cloudwatchlogs")
("runner_name missing" OR "InvalidInstanceID.NotFound" OR "AccessDenied" OR "UnauthorizedOperation" OR "Basic AssumeRole failed" OR "TagSession" OR "Job logs not found" OR "missing_ids" OR "Missing required IDs" OR "invalid_json" OR "archiver_error" OR "Unhandled exception" OR "Failed to start message move task" OR "SQS_MAP is empty" OR "missing_env")
| rex field=source "^[^:]+:/aws/lambda/(?<lambda_function>[^:]+):"
| eval tenant=coalesce(forgecicd_tenant,mvindex(split(lambda_function,"-"),0))
| eval class=case(
    match(_raw,"runner_name missing"),"runner_name missing",
    match(_raw,"InvalidInstanceID.NotFound"),"InvalidInstanceID.NotFound",
    match(_raw,"AccessDenied|UnauthorizedOperation"),"AccessDenied/Unauthorized",
    match(_raw,"Basic AssumeRole failed"),"trust basic assume role failed",
    match(_raw,"TagSession|tag_session"),"trust tag session",
    match(_raw,"Job logs not found"),"job logs not found",
    match(_raw,"missing_ids|Missing required IDs"),"job log missing ids",
    match(_raw,"invalid_json"),"invalid json",
    match(_raw,"missing_env"),"missing env",
    match(_raw,"archiver_error"),"job log archiver error",
    match(_raw,"Unhandled exception"),"unhandled exception",
    match(_raw,"Failed to start message move task"),"dlq redrive failed",
    match(_raw,"SQS_MAP is empty"),"dlq map empty",
    true(),"other")
| stats count as events latest(_time) as latest by tenant lambda_function class
| sort - events
```

Webhook/job-log pipeline:

```spl
search index="srea-forge-prod-index" (sourcetype="aws:cloudwatchlogs:forgecicd" OR sourcetype="aws:cloudwatchlogs")
("Enqueued workflow_job" OR "Ignoring non-workflow_job" OR "Job logs not found" OR "Missing required IDs" OR "archiver_error" OR "invalid_json" OR "redrive")
| rex field=source "^[^:]+:/aws/lambda/(?<lambda_function>[^:]+):"
| eval tenant=coalesce(forgecicd_tenant,mvindex(split(lambda_function,"-"),0))
| eval stage=case(match(lambda_function,"job-log-dispatcher"),"dispatcher", match(lambda_function,"job-log-archiver"),"archiver", match(lambda_function,"redrive-deadletter"),"redrive", true(),"other")
| eval class=case(
    match(_raw,"Enqueued workflow_job"),"enqueued",
    match(_raw,"Ignoring non-workflow_job"),"ignored non-workflow_job",
    match(_raw,"Job logs not found"),"job logs not found",
    match(_raw,"Missing required IDs|missing_ids"),"missing ids",
    match(_raw,"invalid_json"),"invalid json",
    match(_raw,"archiver_error"),"archiver error",
    match(_raw,"Unhandled exception"),"unhandled exception",
    match(_raw,"Started message move task"),"dlq redrive started",
    match(_raw,"Failed to start message move task"),"dlq redrive failed",
    true(),"other")
| stats count as events latest(_time) as latest by tenant lambda_function stage class
| sort - events
```

## References

- Forge ARC uses `actions/actions-runner-controller` runner scale set charts and chart version `0.14.2`.
- ARC upstream says runner scale sets orchestrate and scale ephemeral self-hosted runners, and its troubleshooting guide calls out delayed job allocation, network readiness, stuck backing pods, DIND sidecar boot failures, disk performance, and Docker no-space errors.
- Forge EC2 runners vendor `github-aws-runners/terraform-aws-github-runner` v7.7.1. The upstream module is Lambda-driven, webhook/EventBridge/SQS based, supports ephemeral EC2 runners, runner hooks, CloudWatch runner log files, redrive build queues, SSM, AMI selection, and scale error retry categories.
