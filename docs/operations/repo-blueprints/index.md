# Forge Operations Repo Blueprints

This folder is a copyable operating model for a company that wants to run Forge
as a real platform, not as one large repo with every concern mixed together.

Each subfolder emulates one repository. Copy a folder, rename the repo, replace
the placeholders, then wire the repo into your normal branch protection and
release process.

Start with [Adoption Sequence](adoption-sequence.md) if you are deciding which
repos to create first.

| Repo folder                                                | Owns                                                         | Runtime surface                                                 |
| ---------------------------------------------------------- | ------------------------------------------------------------ | --------------------------------------------------------------- |
| [runner-base-image](runner-base-image/README.md)           | Base AMIs shared by all runner images.                       | Packer, Ansible, AMI publishing                                 |
| [runner-custom-image](runner-custom-image/README.md)       | Custom AMIs built from the base image.                       | Packer, Ansible, tenant or org tools                            |
| [containers](containers/README.md)                         | ECR containers for action runners, pre-commit, and CI tools. | Dockerfiles, ECR push workflow                                  |
| [renovate-config](renovate-config/README.md)               | Dependency automation policy.                                | Renovate config and scheduled workflow                          |
| [cloud-custodian](cloud-custodian/README.md)               | AMI and leftover resource cleanup.                           | Cloud Custodian policies and schedule                           |
| [forge-tenants-iac-aws](forge-tenants-iac-aws/README.md)   | Forge tenants and platform runtime config.                   | Terragrunt tenant stacks                                        |
| [forge-infra-iac-aws](forge-infra-iac-aws/README.md)       | EKS, helper modules, storage, and shared infra.              | Terragrunt infra/helper stacks                                  |
| [forge-examples-iac-aws](forge-examples-iac-aws/README.md) | Weekly apply/destroy tests for Forge examples.               | Generated example Terragrunt runs                               |
| [reusable-actions](reusable-actions/README.md)             | Shared GitHub composite actions.                             | Locking, Terragrunt comments, dynamic actions, workflow helpers |

## Baseline Repo Set

For a small platform team, start with these repos:

```text
forge-runner-base-image
forge-runner-custom-image
forge-containers
forge-renovate-config
forge-cloud-custodian
forge-reusable-actions
forge-infra-iac-aws
forge-tenants-iac-aws
forge-examples-iac-aws
```

Keep Forge module source code in `cisco-open/forge`. These operating repos
consume Forge releases and prove the release can be deployed.

## Common Replacement Values

Replace these before running any workflow:

| Placeholder         | Replace with                                        |
| ------------------- | --------------------------------------------------- |
| `000000000000`      | AWS account ID                                      |
| `eu-west-1`         | Default AWS region                                  |
| `forge-ops-prod`    | AWS profile used by CI                              |
| `owner`             | Deployment role name                                |
| `example.com/forge` | ECR or artifact registry                            |
| `cisco-open/forge`  | Your Forge fork if you do not use upstream directly |
| `FORGE_REF`         | Forge release, branch, or commit SHA                |
| `acme`              | Example tenant name                                 |

## Suggested Ownership

- Image team owns `runner-base-image` and `runner-custom-image`.
- Platform team owns `forge-infra-iac-aws` and `forge-tenants-iac-aws`.
- Developer experience owns `containers` and `renovate-config`.
- Operations owns `cloud-custodian`, `reusable-actions`, and weekly examples.

This split keeps day-to-day changes narrow. A Renovate config change should not
touch EKS. An AMI bake should not touch tenant Terragrunt. A Splunk integration
change should not be required for a company that does not use Splunk.
