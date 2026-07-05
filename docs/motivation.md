# Motivation

ForgeMT exists because a self-hosted runner platform becomes a product once
more than one team depends on it.

The open-source name is ForgeMT: Forge multi-tenancy. Internally and in prose,
people often shorten that to Forge. The public docs use ForgeMT when naming the
project and Forge when readability matters.

GitHub-hosted runners are simple, but they do not solve private AWS access,
custom images, enterprise network controls, or large-volume cost management.
Basic self-hosted runners give control back to the company, but they usually
turn into snowflake instances, shared secrets, manual onboarding, and cleanup
jobs that only one person understands.

ForgeMT is the platform layer between those two extremes. It gives a platform
team a repeatable way to deploy ephemeral GitHub Actions runners on AWS,
separate tenant configuration from runtime modules, and keep day-2 operations
inside repos and pipelines instead of tribal knowledge.

## Design Goals

| Goal                        | What it means in practice                                                                                               |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Fast first deployment       | Start with one GitHub.com org-level tenant runner lane before adding helpers, Splunk, Teleport, or relay targets.       |
| Clear module ownership      | Runtime modules live in `modules/platform`, EKS foundation in `modules/infra`, operations helpers in `modules/helpers`. |
| Optional integrations       | Splunk, Teleport, OpenTelemetry, OpenCost, and relay destinations are useful integrations, not install blockers.        |
| Tenant configuration as IaC | Tenant runner specs, labels, GitHub App settings, AWS role access, and metadata are reviewed through code.              |
| Weekly proof                | Example deployments should be planned, applied, tested, and destroyed on a schedule so docs and modules stay real.      |
| Small-team operations       | Image builds, ECR images, cleanup policies, Renovate, and Terragrunt workflows are documented as copyable repos.        |

## What To Skip First

Do not start by deploying every module.

For the first working tenant, skip anything that is not needed to get one
GitHub Actions workflow running on one runner label:

- skip `modules/infra/eks` unless the first tenant needs ARC runners
- skip `modules/helpers/*` if account bootstrap already created the required
  roles, buckets, AMIs, and repositories
- skip `modules/integrations/*` unless your company already uses that external
  system and has the required secrets ready
- skip the operating repo blueprints until the base platform path is proven

Add those pieces after the platform runtime is working and each addition has a
clear owner.

## Technical Background

These articles explain the architecture and tradeoffs behind Forge. Treat them
as background context; use the docs in this site for the current implementation
and copyable paths.

- [No Silver Bullets: Engineering a Multi-Tenant CI Platform a Small Team Can Run](https://dev.to/edersonbrilhante/no-silver-bullets-engineering-a-multi-tenant-ci-platform-a-small-team-can-run-if)
- [Forge: scalable, secure multi-tenant GitHub runner platform](https://www.linkedin.com/pulse/forge-scalable-secure-multi-tenant-github-runner-brilhante--fyxbf)
- [Scaling GitHub Actions on AWS with ForgeMT's security and multi-tenancy](https://hackernoon.com/scaling-github-actions-on-aws-with-forgemts-security-and-multi-tenancy)
- [No Silver Bullets: engineering a multi-tenant CI platform a small team can run](https://www.linkedin.com/pulse/silver-bullets-engineering-multi-tenant-ci-platform-small-brilhante-ofjpf/)

## Where To Go Next

- [Architecture](architecture.md) explains the platform shape and runtime flows.
- [Getting Started](getting-started/index.md) gives the day-0 and day-1 install
  path.
- [Examples](examples/index.md) maps each real example root to the scenario it
  supports.
