# Configure Helpers

Helpers are operational modules. They prepare accounts and support day-2 work,
but they are not the Forge runner runtime.

Copy from:

```text
examples/deployments/helpers
examples/templates/helpers
```

## Helper Modules

| Helper                 | Use when                                                            | Skip when                                    |
| ---------------------- | ------------------------------------------------------------------- | -------------------------------------------- |
| `opt_in_regions`       | The AWS region is disabled by default.                              | The region is already enabled.               |
| `service_linked_roles` | EC2 Spot or another AWS service role is missing.                    | Your account bootstrap already creates them. |
| `ami_policy`           | You enforce AMI use through account policy.                         | AMI policy is handled elsewhere.             |
| `ami_sharing`          | Runner AMIs are produced in one account and consumed in another.    | AMIs are local to the runner account.        |
| `ecr`                  | Forge owns ECR repos for runner or helper images.                   | Your container platform owns ECR/GHCR.       |
| `storage`              | Forge owns buckets for artifacts, logs, templates, or integrations. | Buckets are provided by another platform.    |
| `cloud_formation`      | An integration needs CloudFormation admin/execution roles.          | No integration needs those roles.            |
| `forge_subscription`   | Tenants need Forge-managed IAM, S3, Packer, ECR, or Secrets access. | Tenant access is managed elsewhere.          |
| `cloud_custodian`      | You want scheduled cleanup and policy sweeps.                       | Another job owns cleanup.                    |

## Files To Change First

```text
examples/deployments/helpers/release_versions.yml
examples/deployments/helpers/terragrunt/_global_settings/_global.yml
examples/deployments/helpers/terragrunt/environments/prod/_environment_wide_settings/_environment.yml
examples/deployments/helpers/terragrunt/environments/prod/regions/eu-west-1/ami_sharing/config.yml
examples/deployments/helpers/terragrunt/environments/prod/regions/eu-west-1/ecr/config.yml
examples/deployments/helpers/terragrunt/environments/prod/cloud_custodian/config.yml
examples/deployments/helpers/terragrunt/environments/prod/forge_subscription/config.yml
```

Delete helper folders you do not use from your operating repo. Keeping unused
helper stacks makes plans noisy and onboarding harder to review.
