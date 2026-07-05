# Real Workflow Files

These pages contain complete workflow files. Copy the file set, change the
small list of values at the top of each page, then run the checks from
[Required Checks](../required-checks.md).

For complete emulated repos, including Packer, Ansible, Dockerfiles,
Renovate, Cloud Custodian, and Terragrunt trees, use
[Forge Operations Repo Blueprints](../repo-blueprints/index.md).

The workflows assume the local composite actions from `.github/actions/` are
present in the target repo. For a live IaC repo, use a
`terragrunt-deployment-action` that handles credentials, locking, plan/apply,
and pull-request comments. For the examples test repo, use the examples repo
variant because it supports `discover`, `apply`, and `destroy`.

| Workflow set                                                            | Copy when you need                                                                       | Files                                                          |
| ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| [IaC promotion and PR plans](iac-promotion.md)                          | Live Terragrunt state for platform, infra, helpers, integrations, or tenants.            | `promotion.yml`, `regression-tests.yml`, `rw-terragrunt.yml`   |
| [ARC/EKS blue-green upgrades](../upgrades.md#arceks-blue-green-upgrade) | Planned EKS, ARC, Karpenter, Calico, or cluster add-on upgrades.                         | top-level regional workflow plus reusable tenant-move workflow |
| [Weekly example deployments](example-deployments.md)                    | A repo that proves Forge examples apply and destroy every week.                          | `test-examples.yml`, `rw-example-category.yml`                 |
| [Scheduled maintenance](scheduled-maintenance.md)                       | Cron-style operational jobs such as Cloud Custodian, stale runner cleanup, or retagging. | One workflow per scheduled job                                 |

## Copy Rules

- Keep workflows small and put repeated logic in local composite actions.
- Discover Terragrunt units from folders instead of editing static matrices.
- Apply live state only from `main` through protected GitHub environments.
- Run examples weekly in this order: helpers, infra, platform, integrations.
- Destroy examples in reverse order.
- Keep optional integrations honest. If you do not use Splunk, leave Splunk
  out of the integrations folder and test the integrations you do use.
