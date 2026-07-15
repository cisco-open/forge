# Module Catalog

This catalog maps every ForgeMT module to its category, install role, example
root, and validation expectation. Use it to decide what belongs in a first
deployment and what can be skipped.

## Platform Modules

| Module                                                       | Role                                              | Required?               | Example root                                        | Validation                                        |
| ------------------------------------------------------------ | ------------------------------------------------- | ----------------------- | --------------------------------------------------- | ------------------------------------------------- |
| `modules/platform/forge_runners`                             | Tenant-facing runner platform entrypoint.         | Yes                     | `examples/deployments/platform`                     | Tenant plan/apply plus EC2 or ARC smoke job.      |
| `modules/platform/ec2_deployment`                            | EC2 ephemeral runner lane.                        | Through `forge_runners` | `examples/deployments/platform`                     | EC2 smoke job launches, registers, and cleans up. |
| `modules/platform/arc_deployment`                            | Tenant ARC runner lane wrapper.                   | Only for ARC            | `examples/deployments/platform`                     | ARC smoke job and scale-set reconciliation.       |
| `modules/platform/arc`                                       | ARC controller and scale-set foundation.          | Only for ARC            | `examples/deployments/infra` and platform ARC specs | `kubectl`, Helm, and ARC resource checks.         |
| `modules/platform/forge_runners/forge_trust_validator`       | Tenant trust validation support.                  | Through `forge_runners` | `examples/deployments/platform`                     | Tenant role trust and workflow role assumption.   |
| `modules/platform/forge_runners/github_actions_job_logs`     | GitHub Actions log archive support.               | Through `forge_runners` | `examples/deployments/platform`                     | Job log archival and reader role checks.          |
| `modules/platform/forge_runners/github_app_runner_group`     | GitHub runner group and app registration support. | Through `forge_runners` | `examples/deployments/platform`                     | Runner group exists and app can register runners. |
| `modules/platform/forge_runners/github_global_lock`          | GitHub lock cleanup support.                      | Through `forge_runners` | `examples/deployments/platform`                     | Lock cleanup Lambda logs and no stale locks.      |
| `modules/platform/forge_runners/github_webhook_relay/source` | GitHub webhook ingress for platform runners.      | Through `forge_runners` | `examples/deployments/platform`                     | GitHub `workflow_job` delivery reaches AWS.       |
| `modules/platform/forge_runners/redrive_deadletter`          | Dead-letter redrive support.                      | Through `forge_runners` | `examples/deployments/platform`                     | DLQ redrive workflow and queue depth checks.      |

## Infrastructure Modules

| Module              | Role                                                 | Required?    | Example root                 | Validation                                           |
| ------------------- | ---------------------------------------------------- | ------------ | ---------------------------- | ---------------------------------------------------- |
| `modules/infra/eks` | EKS foundation for ARC/Kubernetes runner scale sets. | Only for ARC | `examples/deployments/infra` | `kubectl get nodes`, `helm list -A`, ARC pod checks. |

EC2-only deployments can skip `examples/deployments/infra`.

## Helper Modules

| Module                                 | Role                                                         | Required? | Example root                   | Validation                                      |
| -------------------------------------- | ------------------------------------------------------------ | --------- | ------------------------------ | ----------------------------------------------- |
| `modules/helpers/aws_config_recording` | AWS Config history for caller-selected AWS resource types.   | Optional  | `examples/deployments/helpers` | Recorder is active for the configured types.    |
| `modules/helpers/ami_policy`           | AMI policy support for approved runner images.               | Optional  | `examples/deployments/helpers` | Policy plan plus AMI usage review.              |
| `modules/helpers/ami_sharing`          | Shares runner AMIs across accounts or regions.               | Optional  | `examples/deployments/helpers` | Target account can describe and launch AMI.     |
| `modules/helpers/cloud_custodian`      | Cleanup and policy jobs for stale resources.                 | Optional  | `examples/deployments/helpers` | Custodian dry run and scheduled job output.     |
| `modules/helpers/cloud_formation`      | CloudFormation admin/execution roles for setup paths.        | Optional  | `examples/deployments/helpers` | Stack role assumption check.                    |
| `modules/helpers/dedicated_mac_hosts`  | Mac Dedicated Hosts, host groups, and license configuration. | Optional  | `examples/deployments/helpers` | Host allocation and group membership review.    |
| `modules/helpers/ecr`                  | ECR repositories for runner and CI helper containers.        | Optional  | `examples/deployments/helpers` | Push/pull smoke for configured repositories.    |
| `modules/helpers/forge_subscription`   | Tenant-side access for ForgeMT jobs and artifacts.           | Optional  | `examples/deployments/helpers` | Tenant role can access intended S3/ECR/secrets. |
| `modules/helpers/opt_in_regions`       | Enables AWS opt-in regions.                                  | Sometimes | `examples/deployments/helpers` | AWS account region status is enabled.           |
| `modules/helpers/service_linked_roles` | Creates service-linked roles such as EC2 Spot roles.         | Sometimes | `examples/deployments/helpers` | Role exists before EC2 runner launch.           |
| `modules/helpers/storage`              | S3 buckets for artifacts, templates, logs, and integrations. | Optional  | `examples/deployments/helpers` | Bucket policy, encryption, and access checks.   |

Helpers are not runtime platform modules. Deploy them only when ForgeMT owns
that operating concern.

## Integration Modules

| Module                                                            | Role                                                    | Required? | Example root                        | Validation                                        |
| ----------------------------------------------------------------- | ------------------------------------------------------- | --------- | ----------------------------------- | ------------------------------------------------- |
| `modules/integrations/github_webhook_relay_destination`           | Optional webhook forwarding destination.                | No        | `examples/deployments/integrations` | Receiver gets expected GitHub events.             |
| `modules/integrations/github_webhook_relay_destination_receivers` | Optional receiver modules for relay consumers.          | No        | `examples/deployments/integrations` | Receiver-specific smoke event.                    |
| `modules/integrations/splunk_aws_billing`                         | Splunk billing ingestion.                               | No        | `examples/deployments/integrations` | Billing data lands in target index.               |
| `modules/integrations/splunk_cloud_conf_shared`                   | Splunk Cloud saved searches, dashboards, shared config. | No        | `examples/deployments/integrations` | Dashboards and searches exist.                    |
| `modules/integrations/splunk_cloud_data_manager`                  | Splunk Data Manager integration.                        | No        | `examples/deployments/integrations` | Data Manager inputs are active.                   |
| `modules/integrations/splunk_cloud_data_manager_common`           | Shared Data Manager resources.                          | No        | `examples/deployments/integrations` | Shared resources are referenced by consumers.     |
| `modules/integrations/splunk_cloud_s3_runner_logs`                | S3 runner log ingestion to Splunk.                      | No        | `examples/deployments/integrations` | Runner log object produces Splunk event.          |
| `modules/integrations/splunk_o11y_aws_integration`                | Splunk Observability AWS integration.                   | No        | `examples/deployments/integrations` | AWS metrics appear in Splunk Observability.       |
| `modules/integrations/splunk_o11y_aws_integration_common`         | Shared Splunk Observability AWS resources.              | No        | `examples/deployments/integrations` | Shared integration resources exist.               |
| `modules/integrations/splunk_o11y_conf_shared`                    | Splunk Observability dashboards and detectors.          | No        | `examples/deployments/integrations` | Dashboards and detectors exist.                   |
| `modules/integrations/splunk_opencost_eks`                        | OpenCost data path for EKS.                             | No        | `examples/deployments/integrations` | OpenCost metrics reach target backend.            |
| `modules/integrations/splunk_otel_eks`                            | Splunk OpenTelemetry collector on EKS.                  | No        | `examples/deployments/integrations` | Collector pods run and export telemetry.          |
| `modules/integrations/splunk_secrets`                             | Splunk secret placeholders and secret metadata.         | No        | `examples/deployments/integrations` | Secrets exist only when Splunk is used.           |
| `modules/integrations/splunk_stuck_workflow_job_dispatcher`       | Stuck workflow redelivery backed by Splunk data.        | No        | `examples/deployments/integrations` | Dispatcher can identify and redeliver stuck jobs. |
| `modules/integrations/teleport`                                   | Teleport access/audit integration.                      | No        | `examples/deployments/integrations` | Agent joins and access is audited.                |

If your company does not use Splunk, delete the Splunk example folders from
your operating repo. Use [Troubleshooting Without Splunk](../operations/troubleshooting-without-splunk.md)
for the baseline support path.

## Weekly Validation Coverage

Apply from scratch:

```text
helpers -> infra -> platform -> integrations
```

Destroy in reverse:

```text
integrations -> platform -> infra -> helpers
```

The weekly examples repo should include every module family your company
supports. If a category is intentionally skipped, remove it from the matrix and
document why in the repo README.
