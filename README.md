# ForgeMT

[![Release](https://img.shields.io/github/v/release/cisco-open/forge?display_name=tag)](https://github.com/cisco-open/forge/releases/latest/)
[![License](https://img.shields.io/github/license/cisco-open/forge)](LICENSE)
[![Maintainer](https://img.shields.io/badge/Maintainer-Cisco-00bceb.svg)](https://opensource.cisco.com)
[![Docs](https://img.shields.io/badge/docs-GitHub%20Pages-blue.svg)](https://cisco-open.github.io/forge/)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/cisco-open/forge/badge)](https://scorecard.dev/viewer/?uri=github.com/cisco-open/forge)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/10894/badge)](https://www.bestpractices.dev/projects/10894)
![CI](https://img.shields.io/github/check-runs/cisco-open/forge/main)
![Commits since latest release](https://img.shields.io/github/commits-since/cisco-open/forge/latest)
[![Contributors](https://img.shields.io/github/contributors/cisco-open/forge)](https://github.com/cisco-open/forge/graphs/contributors)

ForgeMT is a multi-tenant platform for self-hosted GitHub Actions runners on
AWS. It gives platform teams an IaC-driven way to operate ephemeral EC2 runners
and ARC/Kubernetes runner scale sets for many tenant repositories.

Think of ForgeMT as the runner control plane and operating model, not only a
Terraform module. The platform team owns GitHub App integration, runner images,
AWS placement, tenant configuration, lifecycle cleanup, and optional
observability. Tenant teams consume approved `runs-on` labels and AWS role
access from their workflow YAML.

![Architecture Diagram](./docs/img/10k_ft.jpg)

## What You Get

- Ephemeral self-hosted GitHub Actions runner capacity in AWS.
- EC2 runner lanes for full VM isolation, custom AMIs, Windows, macOS, ARM64, or
  heavier builds.
- ARC runner lanes for Kubernetes-based runner scale sets on EKS.
- Tenant boundaries for labels, IAM/OIDC role access, networks, images, runner
  specs, and GitHub App scope.
- Copyable Terragrunt deployment examples for platform, infra, helpers, and
  integrations.
- Day-2 operating patterns for runner images, ECR images, cleanup, Renovate,
  smoke tests, and optional Splunk/Teleport/OpenTelemetry/OpenCost integrations.

## When To Use It

Use ForgeMT when you need:

- self-hosted GitHub Actions runners inside your AWS accounts.
- tenant boundaries for labels, IAM roles, networks, images, and runner specs.
- reviewed IaC changes for tenant onboarding instead of manual runner setup.
- one operating model for EC2 runners, ARC runners, or both.
- repeatable cleanup, image, upgrade, and validation workflows.

Do not start by deploying every module. The smallest useful install is one
GitHub.com organization, one tenant, one runner lane, and one smoke workflow.
Add helpers, EKS, Splunk, Teleport, OpenCost, OpenTelemetry, and webhook relay
modules only when your operating model needs them.

## Before You Deploy

Have these answers before applying the examples:

| Decision        | Minimum answer                                                                                  |
| --------------- | ----------------------------------------------------------------------------------------------- |
| GitHub target   | GitHub.com or GHES URL, organization, runner group, and GitHub App installation scope.          |
| AWS placement   | Account, region, VPC, subnets, security groups, and tenant AWS role access.                     |
| State backend   | S3 bucket and DynamoDB lock table for Terraform or OpenTofu state.                              |
| First lane      | EC2, ARC on EKS, or both. Start with one lane and add the other after the first smoke workflow. |
| Runner image    | AMI owner/name for EC2 runners or reachable container images for ARC runners.                   |
| Tenant boundary | Tenant name, generated labels, allowed repositories, IAM roles, and metadata ownership.         |
| Integrations    | Which systems are mandatory now and which can be skipped until the runner path works.           |

Pick EC2 first when you already have a runner AMI or need VM-level isolation.
Pick ARC first when EKS is already available and the first workloads fit a
Kubernetes runner model. You can skip EKS for an EC2-only first deployment.

## Module Layout

ForgeMT modules are grouped by operating responsibility:

| Category       | Path                       | Purpose                                                          |
| -------------- | -------------------------- | ---------------------------------------------------------------- |
| Platform       | `modules/platform`         | Forge runtime modules for EC2 and ARC tenant runners.            |
| Infrastructure | `modules/infra`            | EKS foundation for ARC/Kubernetes runner scale sets.             |
| Helpers        | `modules/helpers`          | Account preparation and operations helpers such as AMI, ECR, S3. |
| Integrations   | `modules/integrations`     | Optional external systems such as Splunk, Teleport, and relays.  |
| Examples       | `examples/deployments/...` | Functional Terragrunt roots grouped like the module layout.      |

Splunk is optional. If your company does not use Splunk, skip the Splunk
example folders and all `modules/integrations/splunk_*` modules.

## Quick Start

Start with the platform path:

1. Read [Platform Engineer Quick Start](./docs/getting-started/platform-engineer.md)
   and [Minimal Install](./docs/getting-started/minimal-install.md).
1. Choose the first lane: EC2, ARC, or both.
1. Copy `examples/deployments/platform` into your operations IaC repo.
1. Replace the AWS, GitHub, VPC, runner image, and tenant values.
1. Create or register the GitHub App and store the private key in SSM.
1. Run `terragrunt init`, `terragrunt plan`, and `terragrunt apply`.
1. Queue one smoke workflow with the generated runner labels.

The first install path is the platform example:

```text
examples/deployments/platform
```

After replacing the values and storing the real GitHub App PEM in SSM, run from
the tenant folder:

```bash
cd examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme
terragrunt init
terragrunt plan
terragrunt apply
```

For the full sequence, including backend bootstrap and GitHub App registration,
use [Bootstrap](./docs/getting-started/bootstrap.md) and
[Minimal Install](./docs/getting-started/minimal-install.md).

Read next:

- [ForgeMT documentation](https://cisco-open.github.io/forge/)
- [Motivation](./docs/motivation.md)
- [Architecture](./docs/architecture.md)
- [Examples](./docs/examples/index.md)
- [Operations](./docs/operations/index.md)
- [Security](./docs/security.md)

## Tenant Usage

After the platform team onboards a tenant, repository owners request the runner
with labels generated by ForgeMT:

```yaml
---
name: Forge smoke

on:
  workflow_dispatch:

jobs:
  smoke:
    runs-on:
      - self-hosted
      - type:small
      - x64
      - ec2
      - tnt:acme
    steps:
      - run: echo "Forge runner is online"
```

Tenant teams should use [Tenant Usage](./docs/tenant-usage/index.md) for label,
AWS role, ECR, and troubleshooting patterns.

## Learn More

Technical background:

- [Forge: scalable, secure multi-tenant GitHub runner platform](https://www.linkedin.com/pulse/forge-scalable-secure-multi-tenant-github-runner-brilhante--fyxbf)
- [Scaling GitHub Actions on AWS with ForgeMT's security and multi-tenancy](https://hackernoon.com/scaling-github-actions-on-aws-with-forgemts-security-and-multi-tenancy)
- [No Silver Bullets: engineering a multi-tenant CI platform a small team can run](https://www.linkedin.com/pulse/silver-bullets-engineering-multi-tenant-ci-platform-small-brilhante-ofjpf/)

Implementation foundations:

- [terraform-aws-github-runner](https://github.com/github-aws-runners/terraform-aws-github-runner)
- [actions-runner-controller](https://github.com/actions/actions-runner-controller)

## Contributing

Contributions are welcome via issues or pull requests. See
[CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

Apache 2.0. See [LICENSE](LICENSE).

## Contact

Track progress or open issues on GitHub:
[https://github.com/cisco-open/forge/issues](https://github.com/cisco-open/forge/issues)
