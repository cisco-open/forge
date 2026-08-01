# Splunk Observability Shared Configuration

This module creates the shared Splunk Observability Cloud dashboard group,
operational dashboards, and detectors for Forge. It consumes telemetry that is
already present in Splunk Observability; it does not install collectors or
configure the Splunk AWS integration.

For day-2 use, see the
[Splunk Observability Dashboard Runbook](../../../docs/operations/splunk-o11y-dashboard-runbook.md)
and
[Splunk Observability Dashboard Panel Reference](../../../docs/operations/splunk-o11y-dashboard-panel-reference.md).

## What It Manages

The module creates the configured dashboard group and the following dashboards:

| Dashboard | Purpose | Configuration source |
| --- | --- | --- |
| `Forge Tenant Impact` | First-response tenant issue leaderboards across Lambda, EC2, Kubernetes, SQS, and EBS | `dashboard_variables.forge_impact` |
| `Forge Runner Usage` | EC2 and Kubernetes runner counts, runtime, and adoption by tenant | `dashboard_variables.forge_impact` |
| `Forge Tenant - EC2 Runners` | EC2 runner CPU, memory, disk, network, status checks, and missing-agent visibility | `dashboard_variables.runner_ec2` |
| `Forge Tenant - K8S Runners` | Tenant ARC pod health, capacity, resource use, restarts, and termination reasons | `dashboard_variables.runner_k8s` |
| `Forge ARC Runner Operations` | ARC controller/listener health, runner supply, job throughput, latency, and workflow fingerprints | `dashboard_variables.arc_runner_operations` |
| `Forge Control Plane - Kubernetes` | Cluster platform pods, nodes, Karpenter/networking components, Prometheus, and OTel health | `dashboard_variables.runner_k8s` and `k8s_platform_namespaces` |
| `Forge Tenant - Lambdas` | Invocation, error, throttle, duration, tenant-impact, function, and version views | `dashboard_variables.lambda` |
| `Forge Control Plane - Lambdas` | Invocation, error, throttle, and duration views for functions without a tenant tag | `dashboard_variables.lambda_control_plane` |
| `Forge Control Plane - Kinesis` | Throughput, throttling, consumer lag, operations, and latency for streams without a tenant tag | `dashboard_variables.kinesis_control_plane` |
| `Forge Tenant - SQS` | Queue traffic, backlog, oldest-message age, and dead-letter queue health | `dashboard_variables.sqs` |
| `Forge Control Plane - SQS` | Traffic, backlog, age, state, and DLQ health for queues without a tenant tag | `dashboard_variables.sqs_control_plane` |
| `Forge Tenant - S3` | Daily bucket size, object count, and storage-class inventory for tenant-tagged buckets | `dashboard_variables.s3` |
| `Forge Control Plane - S3` | Daily bucket size, object count, and storage-class inventory for buckets without a tenant tag | `dashboard_variables.s3_control_plane` |
| `Forge Control Plane - AWS Service Limits` | Trusted Advisor limit-usage percentage for each supported AWS service used by Forge | `dashboard_variables.aws_service_limits` |
| `Forge Tenant - DynamoDB` | Capacity, throttling, errors, returned items, and request latency | `dashboard_variables.dynamodb` |
| `Forge Tenant - EBS` | Volume throughput, operations, latency, queueing, state, and IOPS limits | `dashboard_variables.ebs` |
| `Forge Billing and Cost - AWS` | AWS cost and net-cost trends by service and tenant | `dashboard_variables.billing` |
| `Forge Billing and Cost - OpenCost` | Kubernetes CPU and memory allocation cost by tenant | `dashboard_variables.runner_k8s` |
| `Forge External Dependency Health` | Regional GitHub and AWS SSM availability, latency, API rate-limit budget, and probe execution | `dashboard_variables.dependency_probes` |
| `Forge AWS Regional Platform Health` | Regional Lambda throttle rate/count and queued-build SQS backlog, age, and DLQ activity | `dashboard_variables.aws_regional_health` |

It also creates:

- Kubernetes detectors for missing telemetry, Splunk OTel collector health,
  pending tenant pods, and unhealthy platform pods.
- One dependency and workload-health detector per tenant in
  `dashboard_variables.dependency_probes.tenant_names`. Each detector has rules
  for missing probe telemetry, unavailable SSM parameters, unavailable GitHub
  authentication or organization runner APIs, and a low GitHub API rate-limit
  budget.
- One AWS regional platform detector for stable queued-build age, backlog, and
  DLQ thresholds. Lambda throttle panels remain diagnostic-only because their
  observed baselines differ materially by region.

## Dashboard Variable Ownership

Every independently scoped dashboard uses its own `dashboard_variables`
property. In particular, `forge_impact`, `dependency_probes`,
`aws_regional_health`, `lambda_control_plane`, `kinesis_control_plane`,
`sqs_control_plane`, `s3`, `s3_control_plane`, and `aws_service_limits` do not
fall back to `runner_k8s` or another dashboard's tenants or dynamic variables.

`Forge ARC Runner Operations` uses `arc_runner_operations` so its tenant
namespaces and ARC cluster suggestions can evolve independently from the
tenant runner-resource dashboard. `Forge Control Plane - Kubernetes` and the
OpenCost dashboard intentionally reuse `runner_k8s` because they operate on the
same configured Forge clusters and tenant namespaces. The Kubernetes
dashboards and detectors derive their cluster allow-list from the
`k8s.cluster.name` dynamic variable's `values_suggested`. Forge Impact derives
its cluster scope from the `k8s.cluster.name` values configured under
`forge_impact`.

`tenant_names` supplies the tenant selector and, where the underlying
SignalFlow embeds tenant scope, the allowed tenant set. `dynamic_variables`
adds dashboard variables such as AWS region, environment, or Kubernetes
cluster. Keep both aligned with dimensions actually emitted by the relevant
telemetry source.

The tenant selector on the resource and cost dashboards is optional and starts
without a selected tenant, so the initial view remains aggregate. The
configured tenant names are exposed as the restricted selector suggestions for
drill-down.

## Detector Routing

- `detector_name_prefix` prefixes all detector names.
- When `detector_notifications` is `null`, detectors notify
  `Team,<team>`.
- Set `detector_notifications` to an explicit list to route alerts to those
  destinations.
- Set `detector_notifications` to `[]` to create detectors without
  notifications.
- Kubernetes detector thresholds are configured through
  `k8s_detector_config` and `k8s_otel_collector_config`.
- Dependency detectors are always enabled with fixed durations and a fixed
  GitHub rate-limit threshold.
- AWS regional platform detectors are always enabled for the configured
  account, region, and product-family scope. They use the queued-build
  thresholds documented in the dashboard and do not alert on Lambda throttle
  count or region-specific throttle-rate baselines.

## Telemetry and Deployment Prerequisites

- AWS service and billing dashboards require the corresponding metrics and
  tenant tag dimensions from the Splunk AWS integration and billing pipeline.
- The S3 dashboards use the daily `BucketSizeBytes` and `NumberOfObjects`
  metrics. S3 request, latency, transfer, and error charts are omitted until
  those optional request metrics are observed for Forge buckets.
- AWS service limits use `AWS/TrustedAdvisor` `ServiceLimitUsage`, scoped by
  AWS account and the Trusted Advisor `Region` dimension. The dashboard has one
  chart for each supported Forge service observed in that metric.
- AWS regional platform health requires `Throttles`, `Invocations`,
  `ApproximateAgeOfOldestMessage`, `ApproximateNumberOfMessagesVisible`, and
  `NumberOfMessagesSent`, with `aws_account_id`, `aws_region`, and
  `aws_tag_ProductFamilyName` dimensions.
- Kubernetes dashboards and detectors require Kubernetes and collector metrics
  from the Splunk OpenTelemetry Collector.
- `Forge ARC Runner Operations` requires ARC controller and listener
  Prometheus metrics, annotation-based Prometheus autodiscovery, and native
  histogram export from the Splunk OpenTelemetry Collector. The collector must
  preserve `k8s.namespace.name` so the dashboard tenant selector can scope ARC
  metrics by Forge tenant namespace.
- OpenCost dashboards require the OpenCost allocation and node-price metrics.
- Dependency dashboards and detectors require the
  `forge.dependency.*` metrics sent directly by the regional
  `splunk_dependency_monitor` module. The `TenantName`, `AWSRegion`,
  `Provider`, and `CheckName` dimensions must be preserved.
- The deploying AWS account must contain
  `/cicd/common/splunk_o11y_username` and
  `/cicd/common/splunk_o11y_password` in AWS Secrets Manager. The module reads
  those credentials to configure the SignalFx provider.
- Deploy this module after `splunk_secrets`. See the
  [integration configuration template](../../../examples/templates/integrations/splunk_o11y_conf_shared/config.yml)
  for the complete dashboard-variable shape.

## Operational Guidance

- Start with `Forge Tenant Impact` to identify the affected tenant and
  subsystem, then open the matching resource dashboard.
- Use `Forge Runner Usage` for capacity and adoption analysis, not incident
  severity.
- Use `Forge ARC Runner Operations` to trace controller state, registered
  capacity, job throughput, outcomes, startup latency, execution duration, and
  high-cardinality workflow fingerprints.
- Use `Forge Control Plane - Kubernetes` for shared cluster, scheduling,
  networking, Prometheus, and collector problems; use
  `Forge Tenant - K8S Runners` for tenant workload symptoms.
- Use `Forge AWS Regional Platform Health` for regional control-plane Lambda
  throttling and queued-build SQS saturation; use the tenant Lambda and SQS
  dashboards for resource-level drill-down.
- A no-data alert can indicate a collection or ingestion failure rather than a
  Forge workload outage.
- Tune detector durations and thresholds against production behavior to avoid
  alert fatigue.
- Correlate these metric dashboards with the Splunk Cloud log dashboards for
  full incident context.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.47 |
| <a name="requirement_signalfx"></a> [signalfx](#requirement\_signalfx) | < 10.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.57.1 |
| <a name="provider_signalfx"></a> [signalfx](#provider\_signalfx) | 9.33.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_dashboard_arc_runner_operations"></a> [dashboard\_arc\_runner\_operations](#module\_dashboard\_arc\_runner\_operations) | ./dashboards/arc_runner_operations | n/a |
| <a name="module_dashboard_aws_regional_health"></a> [dashboard\_aws\_regional\_health](#module\_dashboard\_aws\_regional\_health) | ./dashboards/aws_regional_health | n/a |
| <a name="module_dashboard_aws_service_limits"></a> [dashboard\_aws\_service\_limits](#module\_dashboard\_aws\_service\_limits) | ./dashboards/aws_service_limits | n/a |
| <a name="module_dashboard_billing"></a> [dashboard\_billing](#module\_dashboard\_billing) | ./dashboards/billing | n/a |
| <a name="module_dashboard_dependency_probes"></a> [dashboard\_dependency\_probes](#module\_dashboard\_dependency\_probes) | ./dashboards/dependency_probes | n/a |
| <a name="module_dashboard_dynamodb"></a> [dashboard\_dynamodb](#module\_dashboard\_dynamodb) | ./dashboards/dynamodb | n/a |
| <a name="module_dashboard_ebs"></a> [dashboard\_ebs](#module\_dashboard\_ebs) | ./dashboards/ebs | n/a |
| <a name="module_dashboard_forge_impact"></a> [dashboard\_forge\_impact](#module\_dashboard\_forge\_impact) | ./dashboards/forge_impact | n/a |
| <a name="module_dashboard_k8s_control_plane"></a> [dashboard\_k8s\_control\_plane](#module\_dashboard\_k8s\_control\_plane) | ./dashboards/k8s_control_plane | n/a |
| <a name="module_dashboard_kinesis_control_plane"></a> [dashboard\_kinesis\_control\_plane](#module\_dashboard\_kinesis\_control\_plane) | ./dashboards/kinesis_control_plane | n/a |
| <a name="module_dashboard_lambda"></a> [dashboard\_lambda](#module\_dashboard\_lambda) | ./dashboards/lambda | n/a |
| <a name="module_dashboard_lambda_control_plane"></a> [dashboard\_lambda\_control\_plane](#module\_dashboard\_lambda\_control\_plane) | ./dashboards/lambda_control_plane | n/a |
| <a name="module_dashboard_opencost"></a> [dashboard\_opencost](#module\_dashboard\_opencost) | ./dashboards/opencost | n/a |
| <a name="module_dashboard_runner_ec2"></a> [dashboard\_runner\_ec2](#module\_dashboard\_runner\_ec2) | ./dashboards/runner_ec2 | n/a |
| <a name="module_dashboard_runner_k8s"></a> [dashboard\_runner\_k8s](#module\_dashboard\_runner\_k8s) | ./dashboards/runner_k8s | n/a |
| <a name="module_dashboard_runner_logs_ingestion"></a> [dashboard\_runner\_logs\_ingestion](#module\_dashboard\_runner\_logs\_ingestion) | ./dashboards/runner_logs_ingestion | n/a |
| <a name="module_dashboard_runner_usage"></a> [dashboard\_runner\_usage](#module\_dashboard\_runner\_usage) | ./dashboards/runner_usage | n/a |
| <a name="module_dashboard_s3"></a> [dashboard\_s3](#module\_dashboard\_s3) | ./dashboards/s3 | n/a |
| <a name="module_dashboard_s3_control_plane"></a> [dashboard\_s3\_control\_plane](#module\_dashboard\_s3\_control\_plane) | ./dashboards/s3_control_plane | n/a |
| <a name="module_dashboard_sqs"></a> [dashboard\_sqs](#module\_dashboard\_sqs) | ./dashboards/sqs | n/a |
| <a name="module_dashboard_sqs_control_plane"></a> [dashboard\_sqs\_control\_plane](#module\_dashboard\_sqs\_control\_plane) | ./dashboards/sqs_control_plane | n/a |
| <a name="module_detector_aws_regional_health"></a> [detector\_aws\_regional\_health](#module\_detector\_aws\_regional\_health) | ./detectors/aws_regional_health | n/a |
| <a name="module_detector_dependency_probes"></a> [detector\_dependency\_probes](#module\_detector\_dependency\_probes) | ./detectors/dependency_probes | n/a |
| <a name="module_detector_ec2_runner_health"></a> [detector\_ec2\_runner\_health](#module\_detector\_ec2\_runner\_health) | ./detectors/ec2_runner_health | n/a |
| <a name="module_detector_k8s"></a> [detector\_k8s](#module\_detector\_k8s) | ./detectors/k8s | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [signalfx_dashboard_group.forgecicd](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/dashboard_group) | resource |
| [aws_secretsmanager_secret.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret_version.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Default AWS region. | `string` | n/a | yes |
| <a name="input_dashboard_group_name"></a> [dashboard\_group\_name](#input\_dashboard\_group\_name) | Name to use for the Splunk Observability dashboard group. | `string` | `"ForgeCICD Dashboards"` | no |
| <a name="input_dashboard_variables"></a> [dashboard\_variables](#input\_dashboard\_variables) | Variables for Dashboards | <pre>object({<br/>    runner_k8s = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    arc_runner_operations = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    runner_ec2 = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    billing = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    sqs = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    s3 = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    ebs = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    lambda = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    lambda_control_plane = object({<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    kinesis_control_plane = object({<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    runner_logs_ingestion = object({<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    sqs_control_plane = object({<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    s3_control_plane = object({<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    aws_service_limits = object({<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    dynamodb = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    dependency_probes = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    aws_regional_health = object({<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    forge_impact = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>  })</pre> | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_detector_name_prefix"></a> [detector\_name\_prefix](#input\_detector\_name\_prefix) | Prefix to use for Splunk Observability detector names. | `string` | `"ForgeCICD"` | no |
| <a name="input_detector_notifications"></a> [detector\_notifications](#input\_detector\_notifications) | Detector notification destinations. When null, detectors notify the configured Splunk Observability team. Set to [] to create detectors without notifications. | `list(string)` | `null` | no |
| <a name="input_k8s_detector_config"></a> [k8s\_detector\_config](#input\_k8s\_detector\_config) | Thresholds and durations for Forge Kubernetes detectors. | <pre>object({<br/>    container_restarts_duration  = string<br/>    container_restarts_threshold = number<br/>    failed_pods_duration         = string<br/>    failed_pods_threshold        = number<br/>    otel_no_data_duration        = string<br/>    otel_no_data_fill_duration   = string<br/>    pending_pods_duration        = string<br/>    pending_pods_threshold       = number<br/>    platform_pods_duration       = string<br/>    platform_unhealthy_threshold = number<br/>  })</pre> | <pre>{<br/>  "container_restarts_duration": "10m",<br/>  "container_restarts_threshold": 0,<br/>  "failed_pods_duration": "5m",<br/>  "failed_pods_threshold": 0,<br/>  "otel_no_data_duration": "10m",<br/>  "otel_no_data_fill_duration": "4h",<br/>  "pending_pods_duration": "10m",<br/>  "pending_pods_threshold": 0,<br/>  "platform_pods_duration": "5m",<br/>  "platform_unhealthy_threshold": 0<br/>}</pre> | no |
| <a name="input_k8s_otel_collector_config"></a> [k8s\_otel\_collector\_config](#input\_k8s\_otel\_collector\_config) | Configuration for Splunk OpenTelemetry Collector health detectors. | <pre>object({<br/>    min_running_pods       = number<br/>    namespace              = string<br/>    no_running_duration    = string<br/>    pod_issue_duration     = string<br/>    pod_name_filter        = string<br/>    restart_duration       = string<br/>    restart_threshold      = number<br/>    stale_metrics_duration = string<br/>  })</pre> | <pre>{<br/>  "min_running_pods": 1,<br/>  "namespace": "splunk-otel-collector",<br/>  "no_running_duration": "10m",<br/>  "pod_issue_duration": "5m",<br/>  "pod_name_filter": "splunk-otel-collector*",<br/>  "restart_duration": "10m",<br/>  "restart_threshold": 0,<br/>  "stale_metrics_duration": "4h"<br/>}</pre> | no |
| <a name="input_k8s_platform_namespaces"></a> [k8s\_platform\_namespaces](#input\_k8s\_platform\_namespaces) | Namespaces that contain platform pods required for runner scheduling and networking. | `list(string)` | <pre>[<br/>  "kube-system",<br/>  "karpenter",<br/>  "calico-system",<br/>  "tigera-operator"<br/>]</pre> | no |
| <a name="input_splunk_api_url"></a> [splunk\_api\_url](#input\_splunk\_api\_url) | URL for plunk Observability Cloud API. | `string` | n/a | yes |
| <a name="input_splunk_organization_id"></a> [splunk\_organization\_id](#input\_splunk\_organization\_id) | organization ID for Splunk Observability Cloud. | `string` | n/a | yes |
| <a name="input_team"></a> [team](#input\_team) | Team ID | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
