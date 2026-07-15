# Platform Engineer Quick Start

This is the shortest path to a working Forge deployment. Use it when you want
one tenant running before adding EKS, helpers, Splunk, Teleport, or other
integrations.

______________________________________________________________________

## What You Need First

Prepare these decisions before touching Terraform or Terragrunt:

| Decision        | Minimum answer                                                                                |
| --------------- | --------------------------------------------------------------------------------------------- |
| AWS accounts    | Which account owns Forge shared infrastructure and which account owns tenant workload access. |
| State backend   | S3 bucket and DynamoDB lock table for Terraform or OpenTofu state.                            |
| GitHub target   | GitHub Cloud with `ghes_url: ''`, or GHES/on-prem URL, organization, and runner group name.   |
| Runner lane     | EC2, ARC on EKS, or both. Start with one lane and add the other after the smoke workflow.     |
| Runner image    | AMI for EC2 runners and container images for ARC runners.                                     |
| Tenant boundary | Tenant name, VPC/subnet placement, tags, and allowed IAM roles.                               |
| Secrets owner   | Where GitHub App credentials and optional integration secrets are stored.                     |

______________________________________________________________________

## Minimum Install Path

1. Install local tools:

   - AWS CLI with access to the target accounts.
   - OpenTofu or Terraform matching the module constraints.
   - Terragrunt if you use the examples in `examples/deployments`.
   - `kubectl` and `helm` only when deploying the ARC/EKS lane.

1. Prepare the runner image:

   - Build or select the base AMI for EC2 runners.
   - Keep the image ID available for tenant runner settings.
   - If using ARC, decide which runner, DinD, and sidecar images tenants can use.

1. Deploy the platform runtime:

   - `modules/platform/forge_runners` is the tenant-facing entry point.
   - `modules/platform/ec2_deployment` is used internally for EC2 runners.
   - `modules/platform/arc_deployment` and `modules/platform/arc` are used when
     the tenant has ARC runner specs.

1. Deploy infrastructure only when needed:

   - `modules/infra/eks` is needed for ARC/Kubernetes runners.
   - You can skip EKS if the first deployment uses only EC2 runner specs.

1. Add helper modules only when your operating model needs them:

   - `modules/helpers/ami_policy` and `modules/helpers/ami_sharing` for AMI
     governance and cross-account sharing.
   - `modules/helpers/ecr` for operational ECR repositories.
   - `modules/helpers/storage` for operational S3 buckets.
   - `modules/helpers/opt_in_regions` for AWS opt-in regions.
   - `modules/helpers/service_linked_roles` for EC2 Spot and AWS service-linked
     roles.
   - `modules/helpers/cloud_formation` for CloudFormation-backed integrations.
   - `modules/helpers/aws_config_recording` for Dedicated Host and instance
     configuration history.
   - `modules/helpers/dedicated_mac_hosts` for EC2 Mac host capacity, host
     groups, and license configuration.
   - `modules/helpers/cloud_custodian` for cleanup and policy jobs.
   - `modules/helpers/forge_subscription` for tenant-side IAM and artifact
     access used by Forge jobs.

1. Add integrations last:

   - Skip all Splunk modules if your company does not use Splunk.
   - Skip Teleport unless your access model requires it.
   - Skip webhook relay destination and receiver modules unless you need
     centralized webhook forwarding.

______________________________________________________________________

## Example Deployment Commands

The example deployments are Terragrunt-based. They read module locations from a
`release_versions.yml` file so the same configuration can use local modules
during development or Git refs in a released environment.

```bash
cd examples/deployments/platform/terragrunt
export RELEASE_VERSION_PATH="$PWD/../../release_versions.yml"
terragrunt run-all init
terragrunt run-all plan
```

For the first deployment, start with the Forge tenant example and omit optional
integration examples. Add EKS only when the first lane is ARC or when you are
ready to run ARC runner scale sets.

______________________________________________________________________

## Next Pages

- [Prerequisites](prerequisites.md)
- [Bootstrap](bootstrap.md)
- [Minimal Install](minimal-install.md)
- [Deployment Order](deployment-order.md)
- [Configure Platform](configure-platform.md)
- [First Tenant](first-tenant.md)

## Optional Splunk Path

Splunk is an integration, not a prerequisite.

Deploy the Splunk example only when all of these are true:

- You have Splunk Cloud or Splunk Observability tenants ready.
- You have the required Splunk credentials in the expected secret paths.
- You want Forge dashboards, detectors, billing ingestion, or stuck-job
  redelivery backed by Splunk data.

If any of those are false, skip:

- `examples/deployments/integrations`
- `modules/integrations/splunk_*`
- [Splunk-specific secrets](../integrations/splunk-secrets.md)

Use your own log or metrics pipeline until the Splunk path is intentionally
adopted.

______________________________________________________________________

## Validation Checklist

Before offering Forge to tenant teams:

- `terraform fmt` or `tofu fmt` passes for changed modules and examples.
- Terragrunt can resolve every `module_path` in the release file.
- EC2 runner labels appear in the target GitHub organization or GHES instance.
- ARC scale sets reconcile if EKS is enabled.
- A test workflow runs on one EC2 label and, if enabled, one ARC label.
- Tenant IAM role assumption works without long-lived AWS keys.
- Optional integrations are either deployed and tested or intentionally skipped.
