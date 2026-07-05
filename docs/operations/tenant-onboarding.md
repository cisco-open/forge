# Tenant Onboarding

Tenant onboarding should be a small, reviewable change to the platform IaC repo.

Use [Tenant Request Template](templates/tenant-request.md) when your company
does not already have an intake form or ticket template.

## Intake Fields

Collect these before editing files:

| Field                             | Example                               |
| --------------------------------- | ------------------------------------- |
| Tenant name                       | `acme`                                |
| GitHub organization or enterprise | `example-org`                         |
| Repositories or runner group      | `acme-platform`, `acme-services`      |
| Environment                       | `prod`                                |
| AWS account IDs                   | `123456789012`                        |
| Region and VPC alias              | `eu-west-1`, `main`                   |
| Runner lane                       | EC2, ARC, or both                     |
| Runner labels                     | `type:small`, `type:dind`, `arm64`    |
| AMI or container image            | AMI ID, ECR image URI                 |
| AWS roles allowed from jobs       | role ARNs                             |
| Required integrations             | none, Splunk, Teleport, webhook relay |
| Support owner                     | team email or issue queue             |

## Support Contract

Agree on ownership before merging the tenant.

| Area             | Platform team owns                              | Tenant team owns                                      |
| ---------------- | ----------------------------------------------- | ----------------------------------------------------- |
| Runner lifecycle | ForgeMT modules, runner groups, labels, cleanup | Choosing the documented labels in workflows           |
| AWS access       | Runner role and allowed role list               | Target role trust, workload permissions, and approval |
| Images           | Base AMIs and approved ARC runner images        | Custom toolchains and custom images                   |
| GitHub App       | App registration path and webhook plumbing      | Repository selection and app installation approval    |
| Support          | Runner start, platform errors, capacity signals | Workflow logic, tests, build scripts, and artifacts   |

The tenant API is the runner label set plus the approved AWS role list. If a
tenant needs a new label, role, image, or repository selection, treat that as a
reviewed config change.

## Change Path

1. Copy the tenant template files.
1. Add the tenant config under `examples/deployments/platform`.
1. Keep EC2 and ARC runner specs separate in review.
1. Keep optional integrations out of the tenant PR unless the tenant needs them
   on day one.
1. Create the GitHub App and put non-secret app metadata in `config.yml`.
1. Create the SSM key parameter with the targeted apply.
1. Replace the placeholder SSM value with the real base64 PEM.
1. Run `terragrunt plan` from the tenant folder.
1. After apply, run a tenant smoke workflow.

## Copy The Tenant Files

Example path used below:

```text
examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme
```

Change `prod`, `eu-west-1`, `main`, and `acme` to match your account, region,
VPC alias, and tenant name.

Run from the repository root:

```bash
export ENV=prod
export REGION=eu-west-1
export VPC=main
export TENANT=acme

export PLATFORM_ROOT=examples/deployments/platform/terragrunt
export TENANT_DIR="$PLATFORM_ROOT/environments/$ENV/regions/$REGION/vpcs/$VPC/tenants/$TENANT"

mkdir -p "$TENANT_DIR"
cp examples/templates/platform/tenant/terragrunt.hcl "$TENANT_DIR/terragrunt.hcl"
cp examples/templates/platform/tenant/runner_settings.hcl "$TENANT_DIR/runner_settings.hcl"
cp examples/templates/platform/tenant/config.yml "$TENANT_DIR/config.yml"
```

Do not create a per-tenant file under `_global_settings`. The current platform
layout uses the shared file:

```text
examples/deployments/platform/terragrunt/_global_settings/tenant.hcl
```

That file is included by every tenant through `find_in_parent_folders`.

## Fill The Tenant Inputs

Edit:

```text
examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme/config.yml
```

These are the values operators normally change first:

| Key                                      | What to put there                                                              |
| ---------------------------------------- | ------------------------------------------------------------------------------ |
| `gh_config.ghes_url`                     | Empty string for GitHub Cloud, or the full GHES/on-prem URL.                   |
| `gh_config.ghes_org`                     | GitHub organization that owns the repositories using the runners.              |
| `gh_config.repository_selection`         | `selected` for selected repositories or `all` for the full org installation.   |
| `gh_config.github_app.*`                 | App ID, client ID, installation ID, and app name from the GitHub App.          |
| `tenant.iam_roles_to_assume`             | Full AWS role ARNs the runners may assume for workloads.                       |
| `tenant.ecr_registries`                  | ECR registries runners are allowed to pull from or push to.                    |
| `tenant.github_logs_reader_role_arns`    | Optional roles that can read archived GitHub Actions logs.                     |
| `ec2_runner_specs.<name>.ami_name`       | AMI name pattern for the runner image, for example `forge-gh-runner-amd64-v*`. |
| `ec2_runner_specs.<name>.ami_owner`      | AWS account ID that owns the AMI.                                              |
| `ec2_runner_specs.<name>.instance_types` | Instance types allowed for that runner size.                                   |
| `arc_runner_specs`                       | Keep `{}` when the tenant uses only EC2; add entries after EKS/ARC is ready.   |
| `arc_cluster_name`                       | Empty when ARC is not enabled; EKS cluster name for ARC tenants.               |

Minimal EC2 runner spec:

```yaml
---
gh_config:
  ghes_url: ''
  ghes_org: example-org
  repository_selection: selected
  github_webhook_relay:
    enabled: false
  github_app:
    id: 1234567890
    client_id: abcdefghijklmnopqrstuvwx
    installation_id: 9876543210
    name: forge-github-app
tenant:
  iam_roles_to_assume:
    - arn:aws:iam::123456789012:role/role_for_forge_runners
  ecr_registries:
    - 123456789012.dkr.ecr.eu-west-1.amazonaws.com
  github_logs_reader_role_arns: []
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
    max_instances: 2
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

For macOS runners, add `use_dedicated_host`, `placement`, and
`license_specifications` when required. Use subnets in the same availability
zone as the dedicated host placement.

For ARC runners, deploy [Infra](../configurations/deployments/infra.md) first,
then add `arc_runner_specs` and set `arc_cluster_name` to the target cluster.

## GitHub Target And Repository Scope

Use GitHub Cloud for the first public install path:

```yaml
gh_config:
  ghes_url: ''
  ghes_org: example-org
```

Use GHES or another on-prem GitHub installation only when the tenant needs it:

```yaml
gh_config:
  ghes_url: https://github.example.com
  ghes_org: example-org
```

The tenant decides repository scope with the platform engineer:

- `repository_selection: selected` when the app is installed only on specific
  repositories.
- `repository_selection: all` when the app is installed for the whole
  organization.

Both are valid. What matters is that the config, GitHub App installation, and
support expectation match.

## Create Or Install The GitHub App

The app must be installed on the org or repositories that will use the runners.
If you use the ForgeMT registration helper, the GitHub App Manifest already
requests the required permissions and the `workflow_job` event. Set or confirm
the app name on the GitHub app creation screen, submit, then download
`forge-github-app.json`.

Install the app on the selected repositories or on the whole organization,
matching the tenant `repository_selection` value.

You need these non-secret values for `config.yml`:

- App ID
- Client ID
- Installation ID
- App name

Keep the private key PEM file outside the repo. You need it only for the SSM
update step below.

## Create The Key Parameter, Then Store The Real PEM

The module manages `/forge/<tenant-region-vpc>/github_app_key` in SSM Parameter
Store and ignores later value changes. Create the parameter first, overwrite it
with the real PEM, then run the full apply.

```bash
cd "$TENANT_DIR"
terragrunt apply -target=aws_ssm_parameter.github_app_key -auto-approve

cd "$(git rev-parse --show-toplevel)"
export AWS_PROFILE=forge-prod
./scripts/update-github-app-secrets.sh "$TENANT_DIR" /absolute/path/to/github-app-private-key.pem
```

You can also update the SSM parameter through the AWS console or with the AWS
CLI. The value must be the base64-encoded PEM without newlines. Do not paste
the PEM into `config.yml`, GitHub Actions logs, pull requests, or tickets.

Use an absolute PEM path and keep the file locked down:

```bash
chmod 600 /absolute/path/to/github-app-private-key.pem
```

## Plan And Apply The Tenant

```bash
cd "$TENANT_DIR"
terragrunt plan
terragrunt apply
```

After apply, check:

- The GitHub App webhook URL and secret were patched.
- The runner group exists in the GitHub organization.
- A workflow using the expected labels can request a runner.
- EC2 instances or ARC pods are created only when jobs are queued.

Example workflow label for the EC2 runner above:

```yaml
runs-on:
  - self-hosted
  - type:small
  - x64
  - ec2
  - tnt:acme
```

## Review Checklist

- Tenant labels are specific enough to avoid landing on the wrong runner.
- Allowed AWS roles are tenant-owned or explicitly approved.
- AMI IDs and container image URIs are from approved sources.
- ARC specs are used only when EKS is deployed.
- GitHub App installation includes the target repositories.
- Splunk, Teleport, and webhook relay settings are absent when unused.
- Tenant request includes a support owner and an escalation path.

## Common Failures

| Symptom                | Check                                                                                                                      |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| GitHub App patch fails | The SSM key value is still the placeholder, the PEM is not base64 encoded by the script, or the App ID/client ID is wrong. |
| Runner never starts    | GitHub App is not installed on the repo/org, `workflow_job` event is missing, or labels do not match.                      |
| AMI lookup fails       | `ami_name`, `ami_owner`, architecture, or AMI sharing is wrong.                                                            |
| EC2 launch fails       | Subnets, security groups, service-linked roles, Spot limits, or instance quotas are missing.                               |
| ARC pods do not start  | EKS is missing, kube access is wrong, or CPU/memory values do not include Kubernetes units.                                |
| macOS runners fail     | Dedicated host placement, host resource group, subnet AZ, or License Manager settings do not match.                        |
