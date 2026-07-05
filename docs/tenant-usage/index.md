# Use Forge Runners

This page is for repository owners who already have access to a ForgeMT tenant.
It shows the workflow labels and AWS patterns you need to run jobs on ForgeMT.

If you are installing ForgeMT itself, use the
[Getting Started](../getting-started/index.md) docs instead.

______________________________________________________________________

## Before You Start

Get these values from the Forge platform team or from your tenant config:

| Value              | Example      | Where it appears                        |
| ------------------ | ------------ | --------------------------------------- |
| Tenant name        | `acme`       | Runner label `tnt:acme`                 |
| Environment        | `prod`       | Runner label `env:ops-prod`             |
| Region alias       | `euw1`       | Runner label `rgn:euw1`                 |
| VPC alias          | `main`       | Runner label `vpc:main`                 |
| EC2 runner type    | `small`      | Runner label `type:small`               |
| CPU architecture   | `x64`        | Runner label `x64` or `arm64`           |
| ARC scale set name | `dependabot` | ARC label such as `dependabot` or `k8s` |
| ARC scale set type | `dind`       | ARC label `type:dind` or `type:k8s`     |

Your repository must also be selected in the tenant GitHub App installation.
If the app is not installed for the repository, the workflow will stay queued.

## Tenant Support Contract

ForgeMT is a platform service. Tenant teams consume the runner API; they do not
operate the runner control plane.

| Tenant team owns                               | Platform team owns                                      |
| ---------------------------------------------- | ------------------------------------------------------- |
| Workflow YAML, build scripts, tests, artifacts | Runner lifecycle, scale up/down, cleanup, and modules   |
| Requested runner labels                        | Label generation, runner groups, and capacity settings  |
| Target AWS role permissions and trust approval | Runner role wiring and allowed role list in tenant IaC  |
| Custom toolchains and custom images            | Base AMIs, ARC runner images, and image publishing path |
| Repository selection request                   | GitHub App registration path and webhook plumbing       |

When asking for support, include the workflow URL, repository, tenant name,
full `runs-on` labels, AWS role ARN, approximate failure time, and whether the
job reached a runner or stayed queued.

______________________________________________________________________

## Pick the Right Runner

| Workload                         | Use                                           | Avoid                                                 |
| -------------------------------- | --------------------------------------------- | ----------------------------------------------------- |
| Normal Linux CI job              | EC2 runner, for example `type:small`          | ARC if the job needs a full VM or custom AMI.         |
| ARM64 build or test              | EC2 runner with `arm64` label                 | `x64` labels.                                         |
| Docker build                     | ARC `type:dind` or an EC2 runner with Docker  | ARC `type:k8s` if the job needs Docker daemon access. |
| Lightweight Kubernetes-style job | ARC `type:k8s`                                | DinD unless Docker daemon access is required.         |
| macOS build                      | Dedicated macOS EC2 runner                    | Generic Linux labels.                                 |
| Dependency automation            | Dedicated Renovate or Dependabot runner label | Running on every push.                                |

Do not use only `self-hosted`. Add enough labels to hit the intended tenant,
environment, and runner type.

______________________________________________________________________

## EC2 Runner Workflow

Use this for a normal Linux runner backed by EC2:

```yaml
---
name: Build

on:
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  build:
    runs-on:
      - self-hosted
      - type:small
      - x64
      - ec2
      - env:ops-prod
      - rgn:euw1
      - vpc:main
      - tnt:acme
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/test.sh
```

For ARM64, change `x64` to `arm64` and use a tenant runner type whose AMI and
instance types support ARM64.

______________________________________________________________________

## ARC Runner Workflows

Use `type:dind` when the job needs Docker daemon access:

```yaml
jobs:
  docker-build:
    runs-on:
      - self-hosted
      - dependabot
      - type:dind
      - x64
      - arc
      - env:ops-prod
      - rgn:euw1
      - vpc:main
      - tnt:acme
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t example .
```

Use `type:k8s` for Kubernetes runner jobs that do not need Docker daemon
access:

```yaml
jobs:
  test:
    runs-on:
      - self-hosted
      - k8s
      - type:k8s
      - x64
      - arc
      - env:ops-prod
      - rgn:euw1
      - vpc:main
      - tnt:acme
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/test.sh
```

The first ARC-specific label, such as `dependabot` or `k8s`, comes from the
tenant `arc_runner_specs.<name>.scale_set_name`.

______________________________________________________________________

## Optional AWS Access

If a workflow needs AWS access, the role ARN must be allowed in the Forge tenant
configuration first. The normal Forge pattern is role chaining: the runner's AWS
role assumes the target role.

```yaml
permissions:
  contents: read

jobs:
  deploy:
    runs-on:
      - self-hosted
      - type:small
      - x64
      - ec2
      - env:ops-prod
      - tnt:acme
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/role_for_forge_runners
          aws-region: eu-west-1
          role-duration-seconds: 3600
          role-chaining: true

      - run: aws sts get-caller-identity
```

If `sts:AssumeRole` fails, the tenant config, target role trust policy, or role
permissions are missing. If your company uses GitHub OIDC instead of runner-role
chaining, use your normal OIDC workflow and target-role trust policy.

______________________________________________________________________

## Private ECR Images

For Docker commands inside a job, authenticate before pulling:

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Configure AWS credentials
    uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789012:role/role_for_forge_runners
      aws-region: eu-west-1
      role-chaining: true

  - name: Login to ECR
    run: |
      aws ecr get-login-password --region eu-west-1 \
        | docker login --username AWS --password-stdin 123456789012.dkr.ecr.eu-west-1.amazonaws.com

  - name: Run container
    run: |
      docker run --rm 123456789012.dkr.ecr.eu-west-1.amazonaws.com/build-image:latest ./test.sh
```

For a GitHub job-level `container:` image from private ECR, confirm with the
platform team first. The runner may need to pull that image before your steps
can authenticate.

______________________________________________________________________

## Optional Dynamic EC2 Labels

Some EC2 runner pools allow controlled dynamic `ghr-*` labels. Use them only
when the tenant config has `enable_dynamic_labels: true` and the platform team
has approved the policy.

Common use case:

```yaml
runs-on:
  - self-hosted
  - type:small
  - x64
  - ec2
  - env:ops-prod
  - tnt:acme
  - ghr-ec2-image-id:ami-0123456789abcdef0
```

Do not use dynamic labels to bypass tenant boundaries, approved AMIs, or quota
controls.

______________________________________________________________________

## Troubleshooting

| Symptom                     | Check                                                                          |
| --------------------------- | ------------------------------------------------------------------------------ |
| Job stays queued            | GitHub App installation, exact labels, runner group access, and tenant name.   |
| Job lands on wrong runner   | Add `tnt:<tenant>`, `env:<env>`, `rgn:<region>`, and `vpc:<vpc>` labels.       |
| Docker build fails on ARC   | Use `type:dind`; `type:k8s` is not for Docker daemon workloads.                |
| AWS assume role fails       | Tenant allowed role list, target role trust policy, and `role-chaining: true`. |
| Private ECR pull fails      | ECR repository policy, login region, and assumed role permissions.             |
| Runner disappears after job | Expected behavior; Forge runners are ephemeral.                                |

For dependency automation, see [Dependency Management](./dependency-management.md).
For platform-side triage without Splunk, see
[Troubleshooting Without Splunk](../operations/troubleshooting-without-splunk.md).
