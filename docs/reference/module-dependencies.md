# Module Dependencies

Use this as the rollout order for ForgeMT. The important rule is simple: get
one platform tenant working first, then add infrastructure, helpers, and
integrations only when they are needed.

______________________________________________________________________

## Practical Rollout Order

| Step | Deploy root or module group                                        | Required?                       | Apply when                                                                 |
| ---- | ------------------------------------------------------------------ | ------------------------------- | -------------------------------------------------------------------------- |
| 1    | State backend, AWS profiles or roles, tags, and account guardrails | Yes                             | Before any Terragrunt stack.                                               |
| 2    | `examples/deployments/helpers`: `opt_in_regions`                   | Only for opt-in regions         | Before deploying resources into regions that are disabled by default.      |
| 3    | `examples/deployments/helpers`: `service_linked_roles`             | Usually for EC2 Spot            | Before EC2 runners if the account lacks required AWS service-linked roles. |
| 4    | Runner AMI build and optional AMI sharing                          | Needed for EC2 runners          | Before tenant EC2 runner specs reference the AMI.                          |
| 5    | `examples/deployments/infra`: EKS                                  | Only for ARC/Kubernetes runners | Before tenant `arc_runner_specs`.                                          |
| 6    | `examples/deployments/platform`: one tenant                        | Yes for Forge runners           | The first real Forge runtime deployment.                                   |
| 7    | `examples/deployments/helpers`: remaining helpers                  | Optional                        | When Forge owns ECR, buckets, tenant subscription roles, or cleanup jobs.  |
| 8    | `examples/deployments/integrations`                                | Optional                        | After the platform path works.                                             |

Do not block a first tenant on Splunk, Teleport, billing, dashboards, or helper
modules your company already provides.

AWS Budgets and spend alerts are account or control-plane guardrails, not
module-local defaults. Keep budget resources in the consuming account bootstrap
or tenant/control-plane deployment so optional infra, helper, and integration
modules do not create duplicate or misleading alerts when they are used outside
the runner runtime.

______________________________________________________________________

## Runtime Modules

| Module                            | Depends on                                                             | Notes                                               |
| --------------------------------- | ---------------------------------------------------------------------- | --------------------------------------------------- |
| `modules/platform/forge_runners`  | Tenant GitHub App values, SSM key parameter, VPC/subnets, runner specs | Main entry point for tenant runners.                |
| `modules/platform/ec2_deployment` | Called by `forge_runners`; runner AMIs; GitHub App                     | EC2 ephemeral runners.                              |
| `modules/platform/arc_deployment` | Called by `forge_runners`; EKS; Kubernetes/Helm access                 | ARC scale sets.                                     |
| `modules/platform/arc`            | EKS cluster and Kubernetes providers                                   | Lower-level ARC controller and scale-set wrapper.   |
| `modules/infra/eks`               | VPC, private subnets, AWS access                                       | Needed only when Forge owns the ARC EKS foundation. |

______________________________________________________________________

## Helper Modules

| Module                                 | Deploy before platform?        | Why                                                              |
| -------------------------------------- | ------------------------------ | ---------------------------------------------------------------- |
| `modules/helpers/opt_in_regions`       | Yes, for opt-in regions        | Regional resources cannot deploy until the region is enabled.    |
| `modules/helpers/service_linked_roles` | Usually, for EC2 Spot          | Some accounts need AWS service-linked roles created first.       |
| `modules/helpers/ami_policy`           | Optional                       | Account policy support for AMI usage.                            |
| `modules/helpers/ami_sharing`          | Yes, if tenant AMIs are shared | Tenant runner specs must be able to find the AMI.                |
| `modules/helpers/ecr`                  | Optional                       | Only if Forge owns runner/helper image repositories.             |
| `modules/helpers/storage`              | Optional                       | Only if Forge owns buckets for logs, artifacts, or integrations. |
| `modules/helpers/cloud_formation`      | Optional                       | Mainly for integrations that need CloudFormation roles.          |
| `modules/helpers/forge_subscription`   | Optional                       | Tenant-side IAM, S3, Secrets Manager, Packer, or ECR access.     |
| `modules/helpers/cloud_custodian`      | No                             | Day-2 cleanup/governance; deploy after policies are reviewed.    |

______________________________________________________________________

## Integration Rules

- No Splunk: skip `modules/integrations/splunk_*` and the Splunk secrets.
- No ARC/EKS: skip `splunk_otel_eks`, `splunk_opencost_eks`, `teleport`, and
  tenant `arc_runner_specs`.
- Existing buckets, roles, or secrets: use those values in `config.yml` and
  skip the matching helper module.
- Webhook relay destination should exist before the platform source forwards
  events to it.

______________________________________________________________________

## Release File Rule

Consumers should read `module_path` from release metadata instead of rebuilding
module paths in Terragrunt code. That keeps source addresses reviewable in one
place and avoids different stacks drifting apart.

```hcl
module_ref = local.use_local_repos ? "${local.module_base}//${local.module_root["module_path"]}" : "${local.module_base}//${local.module_root["module_path"]}?ref=${local.module_version}"
```

Check the category-specific file before rollout:

```text
examples/deployments/platform/release_versions.yml
examples/deployments/infra/release_versions.yml
examples/deployments/helpers/release_versions.yml
examples/deployments/integrations/release_versions.yml
```
