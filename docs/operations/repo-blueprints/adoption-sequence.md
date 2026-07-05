# Repo Blueprint Adoption Sequence

The blueprint folders emulate separate operating repos. That is the recommended
model for a mature ForgeMT platform because each repo has a clear owner and
change rate. Smaller companies can start with one platform-ops repo and keep
the same folders until there is enough activity to split them.

## Recommended Order

| Order | Repo folder                                                | Why first                                                                      |
| ----- | ---------------------------------------------------------- | ------------------------------------------------------------------------------ |
| 1     | [forge-tenants-iac-aws](forge-tenants-iac-aws/README.md)   | Holds the platform tenant runtime and proves the runner path.                  |
| 2     | [runner-base-image](runner-base-image/README.md)           | Needed before EC2 runner specs can launch a tenant smoke workflow.             |
| 3     | [reusable-actions](reusable-actions/README.md)             | Standardizes Terragrunt plans, locks, and comments before more repos use them. |
| 4     | [forge-examples-iac-aws](forge-examples-iac-aws/README.md) | Runs weekly apply/destroy from scratch in the supported dependency order.      |
| 5     | [forge-infra-iac-aws](forge-infra-iac-aws/README.md)       | Adds EKS/ARC and helper modules after the first platform path works.           |
| 6     | [containers](containers/README.md)                         | Publishes runner and CI helper containers for ARC and platform workflows.      |
| 7     | [runner-custom-image](runner-custom-image/README.md)       | Lets tenants build toolchain-specific AMIs from the base image.                |
| 8     | [cloud-custodian](cloud-custodian/README.md)               | Adds scheduled cleanup once the platform creates real resources.               |
| 9     | [renovate-config](renovate-config/README.md)               | Keeps every repo current after workflows and tests can prove dependency bumps. |

Do not create every repo on day one if the first tenant is not running yet.
Start with tenants IaC plus the foundation for the selected runner lane: AMI
builds for EC2, or EKS/container images for ARC. Add operating repos as the
support surface grows.

## Repository Secrets And Variables

Each repo should use OIDC to assume AWS roles instead of long-lived AWS keys.

Common variables:

| Name                  | Used by                         | Meaning                                     |
| --------------------- | ------------------------------- | ------------------------------------------- |
| `AWS_REGION`          | image, IaC, examples, custodian | Default AWS region.                         |
| `AWS_ROLE_TO_ASSUME`  | image, containers, custodian    | OIDC role used by the repo workflow.        |
| `PACKER_VPC_ID`       | runner image repos              | VPC where Packer builders launch.           |
| `PACKER_SUBNET_ID`    | runner image repos              | Subnet where Packer builders launch.        |
| `PACKER_ALLOWED_CIDR` | runner image repos              | CIDR allowed to reach builders.             |
| `FORGE_REF`           | examples and IaC repos          | ForgeMT release, branch, or commit to test. |
| `TERRAGRUNT_PATH`     | IaC repos                       | Root folder used by Terragrunt workflows.   |

Common secrets:

| Name                      | Used by            | Meaning                                            |
| ------------------------- | ------------------ | -------------------------------------------------- |
| `PACKER_GITHUB_API_TOKEN` | runner image repos | Optional token for GitHub release download limits. |
| `RENOVATE_TOKEN`          | renovate-config    | GitHub App token or bot PAT for Renovate.          |
| integration secrets       | integrations only  | Splunk, Teleport, or webhook receiver credentials. |

Keep GitHub App private keys for tenants in AWS SSM Parameter Store, not GitHub
Actions secrets.

## First Milestone

Create the tenants IaC repo skeleton and prepare the selected runner lane.

For an EC2 first lane, create the base-image repo and run the Ubuntu build:

1. Copy `runner-base-image` as a repo root.
1. Set `AWS_REGION`, `AWS_ROLE_TO_ASSUME`, `PACKER_VPC_ID`,
   `PACKER_SUBNET_ID`, and `PACKER_ALLOWED_CIDR`.
1. Run the workflow manually for `target_os=ubuntu`.
1. Copy the published AMI name and owner account into the tenant config.

For an ARC first lane, create the infra and container-image path instead, then
point the tenant `arc_runner_specs` at the reachable image.

## Second Milestone

Create the tenants IaC repo:

1. Copy `examples/deployments/platform` into the repo.
1. Replace account, profile, backend, VPC, tenant, GitHub App, and runner image
   values.
1. Run `terragrunt apply -target=aws_ssm_parameter.github_app_key -auto-approve`.
1. Store the real base64 PEM in the SSM parameter.
1. Run `terragrunt plan` and `terragrunt apply`.
1. Run the tenant smoke workflow.

At this point ForgeMT is useful, even if no helper or integration repo exists
yet.

## Third Milestone

Create the weekly examples repo:

1. Copy `forge-examples-iac-aws` as a repo root.
1. Configure the AWS role and default region.
1. Set the ForgeMT ref to the branch or release under test.
1. Run the workflow manually.
1. Keep the weekly schedule enabled only after manual apply/destroy succeeds.

The weekly validation order is fixed:

```text
apply:   helpers -> infra -> platform -> integrations
destroy: integrations -> platform -> infra -> helpers
```

If a company does not use a category, remove it from the matrix. Do not keep
placeholder stacks that are expected to fail.

## Split Or Single Repo

Use separate repos when:

- image changes should not touch tenant IaC
- CI helper containers have different owners than Terraform
- Renovate policy is shared by many repos
- Cloud Custodian jobs have a different review process
- weekly examples need broad AWS permissions that tenant IaC should not have

Use one platform-ops repo when:

- the platform is still being evaluated
- one small team owns every surface
- branch protection and deployment environments are enough separation
- the first tenant is more important than repo-level boundaries

Even in one repo, keep the same folder boundaries. That makes a later split
mechanical instead of a redesign.
