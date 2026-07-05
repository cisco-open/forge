# Module Layout

ForgeMT organizes modules by operational intent. The goal is to make the install
path obvious and keep optional systems out of the critical path.

______________________________________________________________________

## Layout

```text
modules/
  platform/      Forge runner runtime and internal platform building blocks.
  infra/         Foundational infrastructure for the platform.
  helpers/       Operational helper modules used to run and maintain Forge.
  integrations/  Optional external integrations and vendor-specific modules.
```

Use `platform` first, `infra` only for EKS/ARC foundations, `helpers` when you
need operational support resources, and `integrations` only when your company
uses those external systems.

For a full module-by-module map, see [Module Catalog](module-catalog.md).

______________________________________________________________________

## Platform Modules

| Module                            | Purpose                                                                                                                                              | Directly call it?                              |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| `modules/platform/forge_runners`  | Tenant runner entry point. Wires EC2 and ARC runner specs, GitHub App behavior, trust validation, job logs, relay options, and service catalog data. | Yes. This is the normal tenant-facing module.  |
| `modules/platform/ec2_deployment` | EC2 runner lane backed by `terraform-aws-github-runner`.                                                                                             | Usually through `forge_runners`.               |
| `modules/platform/arc_deployment` | Tenant ARC runner lane wrapper.                                                                                                                      | Usually through `forge_runners`.               |
| `modules/platform/arc`            | Lower-level ARC controller and scale-set Helm wrapper.                                                                                               | No, unless building a custom platform wrapper. |

______________________________________________________________________

## Infrastructure Modules

| Module              | Purpose                                                                                                                        | Required?                      |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------ | ------------------------------ |
| `modules/infra/eks` | Builds the EKS foundation for ARC/Kubernetes runners, including Karpenter, Calico, EBS CSI, CoreDNS, and pod identity support. | Required only for ARC runners. |

EC2-only Forge deployments can skip `modules/infra/eks`.

______________________________________________________________________

## Helper Modules

| Module                                 | Purpose                                                                                     |
| -------------------------------------- | ------------------------------------------------------------------------------------------- |
| `modules/helpers/ami_policy`           | IAM policy support for Forge AMI usage.                                                     |
| `modules/helpers/ami_sharing`          | Shares runner AMIs across accounts or regions.                                              |
| `modules/helpers/cloud_custodian`      | Runs cleanup and policy automation.                                                         |
| `modules/helpers/cloud_formation`      | Creates CloudFormation admin and execution roles used by CloudFormation-backed setup paths. |
| `modules/helpers/ecr`                  | Creates ECR repositories for runner, sidecar, Lambda, or operational images.                |
| `modules/helpers/forge_subscription`   | Creates tenant-side roles and access policies for Forge runner jobs.                        |
| `modules/helpers/opt_in_regions`       | Enables AWS opt-in regions.                                                                 |
| `modules/helpers/service_linked_roles` | Creates AWS service-linked roles used by services such as EC2 Spot.                         |
| `modules/helpers/storage`              | Creates S3 buckets for artifacts, templates, logs, and operational data.                    |

Helpers are useful, but they are not the runner runtime. Deploy them when your
company's operating model requires them.

______________________________________________________________________

## Integration Modules

| Module family                                                | Purpose                                                                                                                          | Required? |
| ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------- | --------- |
| `modules/integrations/splunk_*`                              | Splunk Cloud, Splunk Observability, dashboards, billing ingest, OpenTelemetry, OpenCost, secrets, and stuck-workflow redelivery. | No.       |
| `modules/integrations/teleport`                              | Teleport agents and access/audit integration.                                                                                    | No.       |
| `modules/platform/forge_runners/github_webhook_relay/source` | Internal GitHub webhook ingress used by the Forge tenant runner platform.                                                        | Yes.      |
| `modules/integrations/github_webhook_relay_*`                | GitHub webhook relay destination and receiver modules for external consumers.                                                    | No.       |

Splunk modules are intentionally optional. A company that uses another
observability platform should skip the Splunk deployment example and provide its
own log and metric ingestion path.

______________________________________________________________________

## Release Metadata

Every deployment root should pin both the Forge ref and the module path in
`release_versions.yml` or `release_versions.yaml`. Terragrunt stacks should
read those values instead of rebuilding source addresses in every stack.

```yaml
module_path: modules/helpers/storage
ref: <forge-release-tag-or-commit>
```
