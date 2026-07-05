# Minimal Install

This is the smallest useful ForgeMT deployment: one GitHub.com organization,
one tenant, one runner label, one working smoke workflow.

The first public docs path assumes GitHub.com because it removes one variable
while you prove the platform. Set `gh_config.ghes_url: ''` for GitHub Cloud.
Set `gh_config.ghes_url` to a URL only for GitHub Enterprise Server or another
on-prem GitHub installation.

Repository scope is a tenant/platform support decision. The GitHub App can be
installed on selected repositories or on the whole organization; ForgeMT works
with either as long as `repository_selection` and the app installation match.

The same tenant can support EC2 and ARC runner specs. For the first smoke test,
choose one lane:

- EC2 if you have a runner AMI and want the smallest AWS platform footprint.
- ARC if EKS is already deployed and the tenant needs Kubernetes runners.

Add the other lane after the first workflow proves the GitHub App, labels,
state backend, and tenant AWS access.

## Starting Point

Use the platform example:

```text
examples/deployments/platform
```

The example is intended to be copied into an operating IaC repo. It is also
valid to run from the ForgeMT source checkout while evaluating, as long as you
replace the config values with real AWS and GitHub values.

## Files To Edit

Edit these first:

```text
examples/deployments/platform/release_versions.yml
examples/deployments/platform/terragrunt/_global_settings/_global.yml
examples/deployments/platform/terragrunt/environments/prod/_environment_wide_settings/_environment.yml
examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/_region_wide_settings/_region.hcl
examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/_vpc_wide_settings/_vpc.yml
examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme/config.yml
examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme/runner_settings.hcl
```

## Values To Replace

| File                   | Replace                                                                                         |
| ---------------------- | ----------------------------------------------------------------------------------------------- |
| `release_versions.yml` | ForgeMT ref, module repo, module path, and `use_local_repos` mode.                              |
| `_global.yml`          | product name, project name, GitHub org, account prefix, and owner email.                        |
| `_environment.yml`     | environment name, AWS account ID, default region, and runner group suffix.                      |
| `_region.hcl`          | AWS region and short region alias.                                                              |
| `_vpc.yml`             | VPC ID, Lambda subnets, runner subnets, VPC alias, and optional ARC cluster name.               |
| tenant `config.yml`    | GitHub App metadata, tenant IAM roles, ECR registries, AMI owner/name, and runner specs.        |
| `runner_settings.hcl`  | labels and runtime settings only when the default generated labels are not enough for your API. |

For the first run, keep the runner specs narrow. Use one Linux EC2 runner spec,
one ARC runner spec, or one of each if both foundations are ready. Remove macOS
and large runner variants until the first smoke workflow works.

Minimum EC2 runner spec shape:

```yaml
ec2_runner_specs:
  small:
    type: small
    enable_dynamic_labels: true
    ami_name: forge-gh-runner-amd64-v*
    ami_owner: '123456789012'
    ami_kms_key_arn: ''
    runner_os: linux
    runner_architecture: x64
    runner_user: ubuntu
    max_instances: 1
    instance_types:
      - t3.small
      - t3.medium
    pool_config: []
    volume:
      size: 200
      device_name: /dev/sda1
      iops: 3000
      throughput: 125
      type: gp3
arc_runner_specs: {}
arc_cluster_name: ''
migrate_arc_cluster: false
```

Minimum ARC runner spec shape:

```yaml
ec2_runner_specs: {}
arc_runner_specs:
  k8s:
    runner_size:
      max_runners: 5
      min_runners: 0
    scale_set_name: k8s
    scale_set_type: k8s
    container_images:
      actions_runner: ghcr.io/actions/actions-runner:latest
    container_requests_cpu: 500m
    container_requests_memory: 1Gi
    container_limits_cpu: '1'
    container_limits_memory: 2Gi
    volume_requests_storage_type: gp3
    volume_requests_storage_size: 10Gi
arc_cluster_name: forge-euw1-prod
migrate_arc_cluster: false
```

Use both maps when the first tenant should validate both lanes.

## Build Or Select Runner Images

For EC2, the AMI referenced by `ami_name` and `ami_owner` must already exist and
be launchable in the runner account and region.

Use the [Runner Base Image blueprint](../operations/repo-blueprints/runner-base-image/README.md)
to build the first Ubuntu AMI. The blueprint uses Canonical public Ubuntu AMIs
and Packer/Ansible code that can be copied into a dedicated image repo.

After the AMI build, update:

```yaml
ami_name: <published-ami-name-or-pattern>
ami_owner: '<ami-owner-account-id>'
```

If the AMI is encrypted with a customer KMS key, set `ami_kms_key_arn`.
Otherwise keep it as an empty string.

For ARC, the runner container images in `container_images` must be reachable
from the EKS cluster. Start with the public `actions-runner` image for a smoke
test, then move to your approved ECR/GHCR images.

## Create The GitHub App

Use [Bootstrap](bootstrap.md) for the full GitHub App flow.

Required sequence:

1. Create or register the GitHub App.
1. Install it on selected repositories or on the whole organization.
1. Put App ID, client ID, installation ID, and app name in tenant `config.yml`.
1. Run the targeted apply to create `/forge/<deployment-prefix>/github_app_key`.
1. Replace the placeholder SSM value with the real base64 PEM.
1. Run the full tenant apply.

Commands:

```bash
cd examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme
terragrunt apply -target=aws_ssm_parameter.github_app_key -auto-approve

cd "$(git rev-parse --show-toplevel)"
export AWS_PROFILE=forge-prod
./scripts/update-github-app-secrets.sh \
  "$PWD/examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme" \
  /absolute/path/to/github-app-private-key.pem
```

## Plan And Apply

Run from the tenant folder:

```bash
cd examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme
terragrunt init
terragrunt plan
terragrunt apply
```

Expected result:

- the remote state backend exists or is created
- the GitHub App key SSM parameter contains the real base64 PEM
- ForgeMT creates the runner group and control-plane resources
- no runner capacity stays active unexpectedly while no job is queued
- a queued job can cause an EC2 runner or ARC pod to launch and register

## Smoke Workflow

Add this workflow to a repository selected in the GitHub App installation:

EC2 smoke:

```yaml
name: ForgeMT EC2 smoke

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
      - name: Print runner context
        run: |
          uname -a
          whoami
          env | sort | grep -E '^(GITHUB_|RUNNER_)'
```

ARC smoke:

```yaml
name: ForgeMT ARC smoke

on:
  workflow_dispatch:

jobs:
  smoke:
    runs-on:
      - self-hosted
      - k8s
      - type:k8s
      - x64
      - arc
      - tnt:acme
    steps:
      - name: Print runner context
        run: |
          uname -a
          whoami
          env | sort | grep -E '^(GITHUB_|RUNNER_)'
```

If the workflow stays queued, check:

- the exact labels in the workflow
- GitHub App installation scope
- runner group access
- webhook delivery for `workflow_job`
- CloudWatch logs for the ForgeMT webhook and scale-up Lambdas
- AMI lookup, EC2 capacity errors, ARC controller state, or pod scheduling
  events

Use [Troubleshooting Without Splunk](../operations/troubleshooting-without-splunk.md)
when your company does not deploy the Splunk integration modules.

## Add More Later

After the first tenant works:

1. add more EC2 sizes or architectures
1. add ARC scale sets if EKS was skipped for the first smoke
1. add macOS or Windows only after their AMIs and AWS capacity are ready
1. add helpers for AMI sharing, ECR, storage, cleanup, and region bootstrap
1. add integrations only for systems your company actually uses
