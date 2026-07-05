# Helpers Deployment

Helpers are operational support modules. They are useful when Forge owns AMI
sharing, runner image repositories, S3 buckets, region opt-in, service-linked
roles, Cloud Custodian jobs, or tenant subscription roles. They are not the
runner runtime.

Deploy root:

```text
examples/deployments/helpers/terragrunt
```

Skip any helper that your platform already manages elsewhere.

______________________________________________________________________

## Helper Modules

| Module                                 | Example directory                                 | Use when                                                             |
| -------------------------------------- | ------------------------------------------------- | -------------------------------------------------------------------- |
| `modules/helpers/ami_policy`           | `environments/prod/ami_policy`                    | Forge owns AMI usage policy support.                                 |
| `modules/helpers/ami_sharing`          | `environments/prod/regions/eu-west-1/ami_sharing` | Runner AMIs must be shared across accounts or regions.               |
| `modules/helpers/cloud_custodian`      | `environments/prod/cloud_custodian`               | You run cleanup or governance policies from Forge.                   |
| `modules/helpers/cloud_formation`      | `environments/prod/cloud_formation`               | Integrations need CloudFormation admin/execution roles.              |
| `modules/helpers/ecr`                  | `environments/prod/regions/eu-west-1/ecr`         | Forge owns ECR repositories for runner or helper images.             |
| `modules/helpers/forge_subscription`   | `environments/prod/forge_subscription`            | Tenant accounts need Forge-managed IAM, Packer, S3, or ECR access.   |
| `modules/helpers/opt_in_regions`       | `environments/prod/opt_in_regions`                | You need to enable AWS opt-in regions before regional deploys.       |
| `modules/helpers/service_linked_roles` | `environments/prod/service_linked_roles`          | Spot or related AWS services need service-linked roles.              |
| `modules/helpers/storage`              | `environments/prod/storage`                       | Forge owns operational S3 buckets for logs, artifacts, or templates. |

______________________________________________________________________

## What You Edit

| File                                                            | Change                                                      |
| --------------------------------------------------------------- | ----------------------------------------------------------- |
| `_global_settings/_global.yml`                                  | Team, product, project, GitHub org, and owner defaults.     |
| `environments/prod/_environment_wide_settings/_environment.yml` | AWS account, default region, AWS profile, and remote state. |
| `environments/prod/cloud_custodian/config.yml`                  | Cloud Custodian policies and schedule.                      |
| `environments/prod/forge_subscription/config.yml`               | Tenant account IDs, roles, and subscription permissions.    |
| `environments/prod/opt_in_regions/config.yml`                   | Regions to enable.                                          |
| `environments/prod/regions/eu-west-1/ami_sharing/config.yml`    | AMI names, owners, target accounts, and target regions.     |
| `environments/prod/regions/eu-west-1/ecr/config.yml`            | Repositories and lifecycle settings.                        |
| `release_versions.yml`                                          | Helper module sources, refs, and `module_path` values.      |

Templates live under `examples/templates/helpers` for the helpers with
`config.yml` files.

______________________________________________________________________

## Deploy One Helper

Start with one helper, not the whole category:

```bash
cd examples/deployments/helpers/terragrunt/environments/prod/regions/eu-west-1/ecr
terragrunt plan
terragrunt apply
```

Other common single-helper paths:

```bash
cd examples/deployments/helpers/terragrunt/environments/prod/ami_policy
cd examples/deployments/helpers/terragrunt/environments/prod/cloud_custodian
cd examples/deployments/helpers/terragrunt/environments/prod/forge_subscription
cd examples/deployments/helpers/terragrunt/environments/prod/opt_in_regions
cd examples/deployments/helpers/terragrunt/environments/prod/service_linked_roles
cd examples/deployments/helpers/terragrunt/environments/prod/storage
cd examples/deployments/helpers/terragrunt/environments/prod/regions/eu-west-1/ami_sharing
```

Plan the full helper environment only after the individual helper plans are
understood:

```bash
cd examples/deployments/helpers/terragrunt/environments/prod
terragrunt plan --all
```

______________________________________________________________________

## Common Adoption Order

1. `service_linked_roles` when Spot or other AWS services need bootstrap roles.
1. `opt_in_regions` before deploying into opt-in regions.
1. `ecr` if Forge builds or stores runner/helper images.
1. `ami_sharing` if runner AMIs live in a central image account.
1. `storage` if Forge owns operational buckets.
1. `forge_subscription` when tenant accounts need Forge-managed access.
1. `cloud_custodian` only after cleanup policies are reviewed.

There is no requirement to deploy every helper.
