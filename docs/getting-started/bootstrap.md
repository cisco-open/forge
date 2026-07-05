# Bootstrap

Bootstrap is the account and repository preparation that must exist before a
ForgeMT deployment can plan cleanly. The examples are functional after you
replace their config values, but they still assume your AWS profile can create
or use the remote state backend, deployment roles, VPCs, subnets, AMIs, and
GitHub App values you reference.

## Bootstrap Checklist

| Item                 | Where it is configured                                                                      | Required for first tenant? |
| -------------------- | ------------------------------------------------------------------------------------------- | -------------------------- |
| AWS credentials      | Local AWS profile or CI OIDC role                                                           | Yes                        |
| Remote state backend | `examples/deployments/*/terragrunt/environments/prod/_environment_wide_settings`            | Yes                        |
| VPC and subnets      | `examples/deployments/platform/terragrunt/environments/prod/regions/.../_vpc_wide_settings` | Yes                        |
| Runner image         | tenant `config.yml`                                                                         | Yes                        |
| GitHub App metadata  | tenant `config.yml`                                                                         | Yes                        |
| GitHub App PEM       | SSM Parameter Store                                                                         | Yes                        |
| EKS                  | `examples/deployments/infra`                                                                | Only for ARC               |
| EC2 runner AMI       | `examples/deployments/platform/.../tenants/acme/config.yml`                                 | Only for EC2               |
| ARC runner image     | `examples/deployments/platform/.../tenants/acme/config.yml`                                 | Only for ARC               |
| Helper resources     | `examples/deployments/helpers`                                                              | Sometimes                  |
| Integrations         | `examples/deployments/integrations`                                                         | No                         |

## AWS Profile And Remote State

The Terragrunt examples derive the AWS profile from:

```text
examples/deployments/platform/terragrunt/_global_settings/_global.yml
examples/deployments/platform/terragrunt/environments/prod/_environment_wide_settings/_environment.yml
examples/deployments/platform/terragrunt/environments/prod/_environment_wide_settings/_environment.hcl
```

The default profile name is built from `aws_account_prefix` and `env`. With the
checked-in example values, the profile is:

```text
forge-prod
```

Configure that profile before running Terragrunt:

```bash
aws sso login --profile forge-prod
aws sts get-caller-identity --profile forge-prod
export AWS_PROFILE=forge-prod
```

The environment-wide Terragrunt layer also defines the remote state backend:

```text
bucket:         <aws_account_id>.<git_org>.<project_name>
dynamodb_table: <aws_account_id>.<git_org>.<project_name>
region:         <default_aws_region>
profile:        <default_aws_profile>
```

Terragrunt can create the S3 bucket and DynamoDB lock table when the AWS profile
has permission to create them. If your company pre-creates state backends, keep
the same fields but point them at the approved bucket and table.

Run a backend bootstrap check from the tenant folder:

```bash
cd examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme
terragrunt init
terragrunt plan
```

If the backend does not exist and the profile cannot create it, fix bootstrap
permissions or pre-create the backend before continuing.

## Required AWS Permissions

The first tenant path needs permission to:

- create or use S3 remote state and DynamoDB state locks
- read VPC and subnet data
- read the selected runner AMI, if EC2 runner specs are enabled
- create SSM parameters for the GitHub App key and metadata
- create IAM roles, policies, Lambda functions, SQS queues, EventBridge rules,
  CloudWatch log groups, security groups, and EC2 launch resources used by the
  platform module
- launch and terminate EC2 runners, if EC2 runner specs are enabled
- access the target EKS cluster and Kubernetes APIs, if ARC runner specs are
  enabled
- tag every resource with the configured default tags

Use your normal CI deployment role for apply. Local operators should use the
same AWS profile shape as CI so local and pipeline plans read the same state.

## EC2 Runner AMI

If the first lane is EC2, a valid runner AMI must already exist. Build it from
the [Runner Base Image blueprint](../operations/repo-blueprints/runner-base-image/README.md)
before deploying the platform tenant.

For the checked-in `acme` tenant, the AMI lookup patterns are:

```yaml
ami_name: forge-gh-runner-amd64-v*
ami_owner: '123456789012'
```

Replace the owner account and name pattern with the AMI produced by your image
pipeline. Use the image blueprint workflow or Packer directly:

```bash
cd docs/operations/repo-blueprints/runner-base-image
export AWS_REGION=eu-west-1
export VERSION=manual-$(date +%Y%m%d%H%M%S)
export JOB_ID=manual
export BRANCH=manual
export AMI_ARCH=amd64
export UBUNTU_VERSION=24.04
export PACKER_ALLOWED_CIDR=10.0.0.0/8
export PACKER_VPC_ID=vpc-0123456789abcdef0
export PACKER_SUBNET_ID=subnet-0123456789abcdef0
packer init packer/gha-runner.ubuntu.pkr.hcl
packer validate packer/gha-runner.ubuntu.pkr.hcl
packer build packer/gha-runner.ubuntu.pkr.hcl
```

In a real operating repo, prefer the GitHub workflow from the blueprint so AMIs
are rebuilt weekly and published through reviewable releases.

## GitHub App Bootstrap

Create the GitHub App before the full platform apply. You can create it
manually in GitHub or run the local registration UI:

```bash
docker pull ghcr.io/cisco-open/forge-forge-github-app-register:main
docker run --rm -p 5000:5000 ghcr.io/cisco-open/forge-forge-github-app-register:main
```

Open `http://localhost:5000/` and submit the registration form. The helper uses
the GitHub App Manifest flow, so it already requests the required permissions
and the `workflow_job` event.

On the GitHub app creation screen, set or confirm the app name, then submit.
GitHub creates the app and the helper downloads `forge-github-app.json`.
Install the app on the repositories or organization that will use ForgeMT
runners.

Put non-secret values into tenant `config.yml`:

```yaml
gh_config:
  ghes_url: ''
  ghes_org: example-org
  repository_selection: selected
  github_app:
    id: 1234567890
    client_id: abcdefghijklmnopqrstuvwx
    installation_id: 9876543210
    name: forge-github-app
```

Use `ghes_url: ''` for GitHub Cloud. Use a non-empty `ghes_url` only for GHES
or another on-prem GitHub installation. `repository_selection` should match the
GitHub App installation scope: `selected` when the app is installed on selected
repositories, `all` when the tenant is approved for the whole organization.

Then create the SSM key parameter, update it with the real base64 PEM, and run
the full apply:

```bash
cd examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme
terragrunt apply -target=aws_ssm_parameter.github_app_key -auto-approve

cd "$(git rev-parse --show-toplevel)"
export AWS_PROFILE=forge-prod
./scripts/update-github-app-secrets.sh \
  "$PWD/examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme" \
  /absolute/path/to/github-app-private-key.pem

cd examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme
terragrunt apply
```

If you do not use the script, update the SSM parameter in the AWS console or
with `aws ssm put-parameter`. The value must be the base64-encoded PEM without
newlines.

## What To Bootstrap Later

Do not block the first tenant on optional systems:

- deploy `examples/deployments/infra` only when ARC runners are needed
- deploy helper modules only when ForgeMT owns those helper resources
- deploy integration modules only when your company uses that external system
- move from local commands to CI after the first tenant can run a smoke job
