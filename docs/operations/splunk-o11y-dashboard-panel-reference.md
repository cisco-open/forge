# Splunk Observability Dashboard Panel Reference

This page lists the dashboards and charts created by
`modules/integrations/splunk_o11y_conf_shared`. Use it with the
[Splunk Observability Dashboard Runbook](splunk-o11y-dashboard-runbook.md).

The Terraform definitions are the source of truth for chart names,
SignalFlow, filters, windows, and dashboard layout:

```text
modules/integrations/splunk_o11y_conf_shared/dashboards
modules/integrations/splunk_o11y_conf_shared/detectors
```

## Dashboard Inventory

| Dashboard                         | What it answers                                                                                   | Configuration                                               |
| --------------------------------- | ------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| Forge Tenant Impact               | Which tenants and subsystems show the strongest current failure signals?                          | `dashboard_variables.forge_impact`                          |
| Forge Runner Usage                | How many EC2 and Kubernetes runners are active or were used in the selected window?               | `dashboard_variables.forge_impact`                          |
| Forge Tenant - EC2 Runners        | Are EC2 runner hosts healthy, and which hosts are missing the Splunk OTel agent?                  | `dashboard_variables.runner_ec2`                            |
| Forge Tenant - K8S Runners        | Are tenant ARC runner pods healthy and adequately resourced?                                      | `dashboard_variables.runner_k8s`                            |
| Forge Control Plane - Kubernetes  | Are shared cluster, node, platform pod, and telemetry components healthy?                         | `dashboard_variables.runner_k8s`, `k8s_platform_namespaces` |
| Forge Tenant - Lambdas            | Are Forge Lambdas failing, throttled, slow, or concentrated on a function version?                | `dashboard_variables.lambda`                                |
| Forge Tenant - SQS                | Are Forge queues accumulating work or dead-letter messages?                                       | `dashboard_variables.sqs`                                   |
| Forge Tenant - DynamoDB           | Are Forge support tables throttled, slow, or returning errors?                                    | `dashboard_variables.dynamodb`                              |
| Forge Tenant - EBS                | Are Forge volumes saturated, slow, unavailable, or exceeding IOPS limits?                         | `dashboard_variables.ebs`                                   |
| Forge Billing and Cost - AWS      | Which tenants and AWS services drive billed cost?                                                 | `dashboard_variables.billing`                               |
| Forge Billing and Cost - OpenCost | Which Kubernetes tenants and pods drive allocated compute cost?                                   | `dashboard_variables.runner_k8s`                            |
| Forge External Dependency Health  | Can each regional tenant probe AWS SSM and the configured GitHub API, and is its API budget safe? | `dashboard_variables.dependency_probes`                     |

## Forge Tenant Impact

This is the incident landing dashboard. Its charts rank affected tenants while
preserving the tenant and resource dimensions needed for drill-down.

| Chart                                      | Operational question                                          |
| ------------------------------------------ | ------------------------------------------------------------- |
| Top 10 tenants: Lambda errors              | Which tenants have the most Lambda errors?                    |
| Top 10 tenants: Lambda throttles           | Which tenants are experiencing Lambda throttling?             |
| Top 10 tenants: EC2 memory utilization     | Which tenants have the highest EC2 runner memory pressure?    |
| Top 10 tenants: EC2 CPU utilization        | Which tenants have the highest EC2 runner CPU pressure?       |
| Top 10 tenants: K8S pending pods           | Which tenant namespaces have unscheduled runner pods?         |
| Top 10 tenants: K8S failed or unknown pods | Which tenant namespaces have failed or unknown pods?          |
| Top 10 tenants: SQS visible backlog        | Which tenants have the largest visible queue backlog?         |
| Top 10 tenants: SQS dead-letter backlog    | Which tenants have the largest DLQ backlog?                   |
| Top 10 tenants: EC2 disk utilization       | Which tenants have the highest runner filesystem utilization? |
| Top 10 tenants: EC2 status check failures  | Which tenants have EC2 instance or system health failures?    |
| Top 10 tenants: K8S container restarts     | Which tenants have the most restarting containers?            |
| Top 10 tenants: EBS queue length           | Which tenants have the greatest EBS queue pressure?           |
| Top 10 tenants: EBS IOPS limit exceeded    | Which tenants have volumes reporting an exceeded IOPS limit?  |

## Forge Runner Usage

This dashboard is for adoption, capacity, and usage analysis. It is not an
availability score.

| Chart                                            | Operational question                                        |
| ------------------------------------------------ | ----------------------------------------------------------- |
| Total runners by runtime over selected window    | How many distinct EC2 and Kubernetes runners were observed? |
| Runner-minutes by runtime over selected window   | How much runner time was consumed by each runtime?          |
| Active EC2 runners by tenant and instance type   | How does live EC2 capacity change over time?                |
| Active EC2 runners by tenant                     | Which tenants currently have EC2 runners?                   |
| Active EC2 runners by tenant and instance type   | Which instance types make up each tenant's live capacity?   |
| Total EC2 runners by tenant over selected window | How many distinct EC2 runners did each tenant use?          |
| EC2 runner-minutes by tenant                     | How much EC2 runner time did each tenant consume?           |
| EC2 runner-minutes by tenant and instance type   | Which instance types contributed to EC2 runner time?        |
| Active K8S runners by tenant                     | Which tenant namespaces currently have active runner pods?  |
| Total K8S runners by tenant over selected window | How many distinct Kubernetes runners did each tenant use?   |
| K8S runner-minutes by tenant                     | How much Kubernetes runner time did each tenant consume?    |

## Forge Tenant - EC2 Runners

| Chart                                   | Operational question                                         |
| --------------------------------------- | ------------------------------------------------------------ |
| # Disk ops                              | What is the aggregate read/write operation rate?             |
| Total memory overview (bytes)           | How much host memory is used, cached, buffered, or free?     |
| Network out (bytes) vs. 24h change (%)  | Did outbound traffic change materially from the prior day?   |
| Network out (bytes)                     | Which hosts or tenants produce outbound traffic?             |
| Top instances by CPU utilization (%)    | Which EC2 runners have the highest CPU utilization?          |
| Disk utilization (%)                    | Which runner filesystems are approaching capacity?           |
| Disk metrics 24h change (%)             | Which tenants have unusual disk changes?                     |
| Top images by mean CPU utilization (%)  | Are particular runner images associated with high CPU?       |
| Network in (bytes)                      | Which hosts or tenants receive the most traffic?             |
| Memory utilization (%)                  | Which hosts are under memory pressure?                       |
| Top instances by memory utilization (%) | Which individual runners use the most memory?                |
| Disk I/O (bytes)                        | Which tenants generate the most disk I/O?                    |
| Network in (bytes) vs. 24h change (%)   | Did inbound traffic change materially from the prior day?    |
| Network errors/sec                      | Are host interfaces reporting receive or transmit errors?    |
| Top memory page swaps/sec               | Which hosts are swapping memory?                             |
| # Active hosts per instance type        | What instance types make up live runner capacity?            |
| CPU utilization (%)                     | How is CPU changing by instance?                             |
| # Active hosts by availability zone     | Is runner capacity distributed across availability zones?    |
| Disk summary utilization (%)            | Which mountpoints and hosts have the highest utilization?    |
| # Hosts with agent installed            | How many runner hosts emit host-level OTel metrics?          |
| Top 5 network out (bytes)               | Which hosts send the most traffic?                           |
| # Active hosts                          | How many EC2 runners are visible through AWS metrics?        |
| Active hosts missing Splunk OTel agent  | Which AWS-visible runners lack corresponding host telemetry? |
| Top 5 network in (bytes)                | Which hosts receive the most traffic?                        |
| EC2 status check failures               | Are instance or AWS system status checks failing?            |

## Forge Tenant - K8S Runners

| Chart                                       | Operational question                                                      |
| ------------------------------------------- | ------------------------------------------------------------------------- |
| # Available pods by deployments             | How many deployment pods are available?                                   |
| Top 10 CPU usage per pod (CPU units)        | Which tenant pods use the most CPU?                                       |
| Network bytes / sec                         | What is pod network throughput?                                           |
| # Desired pods by deployments               | How many deployment pods are requested?                                   |
| Network errors / sec                        | Which pods or nodes report network errors?                                |
| Memory usage (%)                            | Which containers approach their memory limits?                            |
| # Active pods                               | How many tenant pods are running?                                         |
| Top 10 pods by average memory usage (bytes) | Which pods consume the most memory?                                       |
| # Pods by phase                             | How many tenant pods are pending, running, succeeded, failed, or unknown? |
| Memory usage (bytes)                        | How does pod memory usage change over time?                               |
| Pod phase trend                             | Are pending, failed, or unknown pods accumulating?                        |
| Container restarts                          | Which tenant containers restart most frequently?                          |
| Pod termination and shutdown reasons        | Why are tenant pods terminating or shutting down?                         |

## Forge Control Plane - Kubernetes

| Chart                                 | Operational question                                                         |
| ------------------------------------- | ---------------------------------------------------------------------------- |
| Platform pod health                   | Are configured platform namespace pods running, pending, failed, or unknown? |
| Splunk OTel collector pod health      | Are collector pods running and stable?                                       |
| Node pressure conditions              | Are nodes reporting memory, disk, PID, or network pressure?                  |
| OTel exporter queue utilization       | Is the collector exporter queue approaching capacity?                        |
| OTel refused and failed metric points | Is the collector dropping, refusing, or failing metric points?               |

The platform namespace scope includes `k8s_platform_namespaces` plus
`monitoring`, `prometheus`, and `splunk-otel-collector`.

## Forge Tenant - Lambdas

| Chart                              | Operational question                                            |
| ---------------------------------- | --------------------------------------------------------------- |
| % invocations by version           | What share of invocations is handled by each function version?  |
| Errors by version                  | Which functions and versions are failing?                       |
| Total throttles                    | Are Lambda invocations being throttled?                         |
| Average duration by version        | Which function versions are slow?                               |
| Average invocation duration        | Is aggregate execution time increasing?                         |
| Throttles by version               | Which function versions are throttled?                          |
| Invocations by version             | Which versions receive traffic?                                 |
| Invocations                        | How does invocation volume change by function and version?      |
| Total errors                       | How many Lambda errors are occurring?                           |
| Total invocations                  | How many Lambda invocations are occurring?                      |
| Top 10 tenants by Lambda errors    | Which tenants have the most Lambda errors?                      |
| Top 10 tenants by Lambda throttles | Which tenants have the most Lambda throttles?                   |
| Top 10 Lambdas by errors           | Which tenant, function, and version combinations fail most?     |
| Top 10 Lambdas by throttles        | Which tenant, function, and version combinations throttle most? |

## Forge Tenant - SQS

| Chart                          | Operational question                                  |
| ------------------------------ | ----------------------------------------------------- |
| # Queues                       | How many SQS queues are visible?                      |
| Top queues by message sent     | Which queues receive the most new work?               |
| Sent message size              | Are payload sizes changing or unusually large?        |
| Messages by state              | How many messages are visible, in flight, or delayed? |
| Oldest message age             | Which queues have the oldest unprocessed work?        |
| # Empty receives               | Are consumers polling queues without finding work?    |
| Top queues by message received | Which queues are consumed most heavily?               |
| Message processing trend       | Do sent, received, and deleted counts move together?  |
| # Messages deleted             | Are consumers completing and deleting work?           |
| Visible backlog by tenant      | Which tenants have visible queued work?               |
| DLQ backlog trend              | Are dead-letter messages accumulating?                |
| DLQ oldest message age         | How long have the oldest DLQ messages remained?       |
| DLQ visible messages           | Which dead-letter queues contain messages?            |

## Forge Tenant - DynamoDB

| Chart                                 | Operational question                                      |
| ------------------------------------- | --------------------------------------------------------- |
| Write throttle events                 | Are writes exceeding provisioned capacity?                |
| System errors                         | Is DynamoDB returning service-side errors?                |
| Percentage of read capacity consumed  | How close are tables to provisioned read capacity?        |
| Returned item count                   | Is item-return volume changing by table and operation?    |
| Average request latency (ms)          | What is current and trended successful-request latency?   |
| Throttled requests                    | What is the current and trended throttled-request volume? |
| User errors                           | What is the current and trended client-error volume?      |
| Read throttle events                  | Are reads exceeding provisioned capacity?                 |
| Percentage of write capacity consumed | How close are tables to provisioned write capacity?       |

Some names appear twice because the dashboard deliberately provides both a
single-value summary and a time-series view.

## Forge Tenant - EBS

| Chart                      | Operational question                                           |
| -------------------------- | -------------------------------------------------------------- |
| Byte utilization %         | Are Nitro volumes approaching their byte-throughput allowance? |
| Write latency (ms/op)      | Is write latency increasing?                                   |
| # Read ops                 | What is the read operation rate?                               |
| Write throughput           | What write throughput is delivered?                            |
| Read/write bytes breakdown | How does read traffic compare with write traffic?              |
| Read latency (ms/op)       | Is read latency increasing?                                    |
| Read throughput            | What read throughput is delivered?                             |
| State                      | Are volumes reporting expected state metrics?                  |
| Total read time            | How much time is spent servicing reads?                        |
| Latency/op (ms)            | How do calculated read and write latencies compare?            |
| Total write time           | How much time is spent servicing writes?                       |
| Read vs write ops          | How does read operation rate compare with write rate?          |
| Average queue length       | Are I/O requests waiting on the volume?                        |
| Idle time                  | Is the volume continuously busy?                               |
| # Write ops                | What is the write operation rate?                              |
| Volume IOPS exceeded       | Is the volume reporting an exceeded IOPS allowance?            |

## Forge Billing and Cost - AWS

| Chart                       | Operational question                                 |
| --------------------------- | ---------------------------------------------------- |
| Cost per service            | Which AWS services drive gross cost?                 |
| Net Cost per service        | Which AWS services drive net cost after adjustments? |
| Net Cost per tenant         | Which tenants drive net cost?                        |
| Cost per tenant             | Which tenants drive gross cost?                      |
| Total Cost                  | What is the total cost trend?                        |
| Total Net Cost              | What is the total net-cost trend?                    |
| Runner-related net cost     | What does the runner-related service subset cost?    |
| Top tenant/service net cost | Which tenant and service combinations cost the most? |

## Forge Billing and Cost - OpenCost

| Chart                           | Operational question                                          |
| ------------------------------- | ------------------------------------------------------------- |
| Tenant hourly compute cost      | What is each tenant's current CPU and memory allocation cost? |
| Tenant monthly compute run rate | What monthly run rate does current allocation imply?          |
| Tenant compute cost trend       | How does allocated compute cost change over time?             |
| Tenant CPU cost                 | How much cost is attributed to CPU allocation?                |
| Tenant memory cost              | How much cost is attributed to memory allocation?             |
| Top pod compute cost            | Which pods have the highest allocated compute cost?           |

OpenCost values are allocation estimates, not AWS invoice charges.

## Forge External Dependency Health

| Chart                        | Operational question                                                                       |
| ---------------------------- | ------------------------------------------------------------------------------------------ |
| GitHub checks by tenant      | Can the regional monitor authenticate the GitHub App and call the organization runner API? |
| AWS SSM access by tenant     | Can the regional monitor read the tenant's GitHub App and routing parameters?              |
| GitHub API rate-limit budget | What percentage of the installation token's REST API budget remains?                       |
| Dependency check latency     | How long do AWS SSM and GitHub checks take?                                                |
| Regional probe execution     | Is each tenant and regional monitor cycle still executing?                                 |

These charts use the direct-ingest metrics:

- `forge.dependency.availability`
- `forge.dependency.latency_ms`
- `forge.dependency.probe_executed`
- `forge.dependency.rate_limit_remaining_pct`

Preserve `TenantName`, `AWSRegion`, `RegionAlias`, `Provider`, and `CheckName`
when sending these metrics.

## Reading Rules

- Prove freshness before interpreting an empty chart as healthy.
- Apply tenant, region, cluster, function, queue, table, volume, or instance
  filters before assigning ownership.
- A chart can aggregate several resources. Read its legend dimensions before
  treating the value as a single resource.
- Treat a count without a denominator as impact evidence, not an error rate.
- Compare current values with the chart window and workload demand. Idle
  systems legitimately have sparse metrics.
- Use `Forge Tenant Impact` to find the affected tenant and subsystem, then
  use the narrow dashboard for resource identity.
- Use Splunk Observability for availability and resource pressure. Use the
  [Splunk Cloud Dashboard Runbook](splunk-dashboard-runbook.md) for event
  sequence, errors, and raw evidence.
