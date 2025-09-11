# Deploy a New Tenant

This checklist tells you *exactly* what to update to onboard a new Forge tenant.

______________________________________________________________________

## 1. Create Tenant Config Files

Copy these templates and place them at the correct paths.

### Templates to Copy

- `examples/templates/tenant/_global_settings/tenant.hcl`
- `examples/templates/tenant/tenant/terragrunt.hcl`
- `examples/templates/tenant/tenant/runner_settings.hcl`
- `examples/templates/tenant/tenant/config.yaml`

### Destination Paths

```
examples/deployments/forge-tenant/terragrunt/_global_settings/tenants/<tenant_name>.hcl

examples/deployments/forge-tenant/terragrunt/environments/<aws_account>/regions/<aws_region>/vpcs/<vpc_alias>/tenants/<tenant_name>/terragrunt.hcl

examples/deployments/forge-tenant/terragrunt/environments/<aws_account>/regions/<aws_region>/vpcs/<vpc_alias>/tenants/<tenant_name>/runner_settings.hcl

examples/deployments/forge-tenant/terragrunt/environments/<aws_account>/regions/<aws_region>/vpcs/<vpc_alias>/tenants/<tenant_name>/config.yaml
```

### Example for tenant=`sbg`, account=`sec-plat`, region=`eu-west-1`, vpc_alias=`shared`

```bash
cp examples/templates/tenant/_global_settings/tenant.hcl \
   examples/deployments/forge-tenant/terragrunt/_global_settings/tenants/sbg.hcl

mkdir -p examples/deployments/forge-tenant/terragrunt/environments/sec-plat/regions/eu-west-1/vpcs/shared/tenants/sbg

cp examples/templates/tenant/tenant/terragrunt.hcl \
   examples/deployments/forge-tenant/terragrunt/environments/sec-plat/regions/eu-west-1/vpcs/shared/tenants/sbg/terragrunt.hcl

cp examples/templates/tenant/tenant/runner_settings.hcl \
   examples/deployments/forge-tenant/terragrunt/environments/sec-plat/regions/eu-west-1/vpcs/shared/tenants/sbg/runner_settings.hcl

cp examples/templates/tenant/tenant/config.yaml \
   examples/deployments/forge-tenant/terragrunt/environments/sec-plat/regions/eu-west-1/vpcs/shared/tenants/sbg/config.yaml
```

______________________________________________________________________

## 2. Edit `config.yaml` — Tenant Configuration Fields

Controls GitHub integration, IAM roles, runner specs (EC2 & ARC).

______________________________________________________________________

### Top-level Structure & Key Fields

```yaml
gh_config:
  ghes_url: <GITHUB_URL>              # Empty string for github.com, full GHES URL otherwise
  ghes_org: <GITHUB_ORG>              # Exact GitHub organization name

tenant:
  iam_roles_to_assume:                # List of full AWS IAM role ARNs for runner assume roles
    - arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME>
  ecr_registries:                    # Allowed ECR repo URLs (full), e.g. 123456789012.dkr.ecr.us-east-1.amazonaws.com
    - <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com

ec2_runner_specs:
  <runner_type>:                     # e.g. small, medium, gpu
    ami_name: <AMI_NAME_PATTERN>    # AMI name pattern, supports wildcard *, e.g. forge-gh-runner-v*
    ami_owner: <ACCOUNT_ID>         # AWS account ID owning AMI
    ami_kms_key_arn: ''             # Set to '' if AMI is unencrypted, else KMS ARN string
    max_instances: <MAX_PARALLEL>   # Max EC2 runners allowed in parallel
    instance_types:                 # List of allowed instance types (prefer spot-compatible)
      - <AWS_INSTANCE_TYPE>         # e.g. t3.large, m5.large
    pool_config:                    # Warm pool config for pre-warming runners; empty list [] disables
      - size: <POOL_SIZE>           # Number of instances to keep warm
        schedule_expression: <AWS_CRON_EXPR>  # AWS cron expression (6 fields, use AWS docs)
        schedule_expression_timezone: <TIMEZONE>  # Optional timezone, e.g. UTC, America/New_York

arc_runner_specs:
  <runner_type>:                    # e.g. dependabot, k8s
    runner_size:
      max_runners: <MAX>            # Max pods/runners (Max Pod allowed in parallel)
      min_runners: <MIN>            # Min pods/runners (warm pool)
    scale_set_name: <NAME>          # Used for ARC annotations and scale set identification
    scale_set_type: <dind|k8s>      # Must be exactly 'dind' or 'k8s', no other values allowed
    container_actions_runner: <ECR_IMAGE_URL>   # Full ECR container image URL for the runner container
    container_requests_cpu: <CPU>   # Kubernetes CPU requests, e.g. 500m (mandatory unit)
    container_requests_memory: <MEM> # Kubernetes memory requests, e.g. 1Gi (mandatory unit)
    container_limits_cpu: <CPU>     # Kubernetes CPU limits
    container_limits_memory: <MEM>  # Kubernetes memory limits

```

______________________________________________________________________

### Field Guidance & Gotchas

- **`ghes_url`**: empty for github.com, full URL for GHES.
- **`iam_roles_to_assume`**: full ARNs only, no wildcards.
- **`ecr_registries`**: must be full URLs, including account and region.
- **`ami_kms_key_arn`**: must be explicitly set to `''` if AMI not encrypted; otherwise runner fails.
- **`max_instances`**: check AWS EC2 quota before setting.
- **`instance_types`**: spot-compatible preferred for cost savings.
- **`pool_config.schedule_expression`**: AWS cron syntax with 6 fields, **not** standard cron. Example: `cron(0 8 * * ? *)`. See [AWS docs](https://docs.aws.amazon.com/eventbridge/latest/userguide/scheduled-events.html#cron-expressions).
- **`scale_set_type`**: only `dind` or `k8s`. Wrong values cause runtime errors.
- **Kubernetes CPU/memory fields**: units mandatory (e.g., `500m`, `1Gi`). Missing units break pods.

______________________________________________________________________

### Common Pitfalls — Avoid These

- Wildcard or invalid IAM roles → runner startup failures.
- Forgetting `ami_kms_key_arn` = `''` when AMI isn’t encrypted → Terraform errors.
- Incorrect cron syntax → scheduled warm pools don’t trigger.
- Setting max runners beyond quotas → failures or throttling.
- Missing units in k8s resource requests/limits → pod rejection.

______________________________________________________________________

## 3. Minimal Working `config.yaml` Example

```yaml
gh_config:
  ghes_url: ''
  ghes_org: cisco-sbg

tenant:
  iam_roles_to_assume:
    - arn:aws:iam::123456789012:role/role_for_forge_runners
  ecr_registries:
    - 123456789012.dkr.ecr.us-east-1.amazonaws.com

ec2_runner_specs:
  small:
    ami_name: forge-gh-runner-v*
    ami_owner: '123456789012'
    ami_kms_key_arn: ''
    max_instances: 10
    instance_types:
      - t3.small
      - t3.medium
    pool_config:
      - size: 2
        schedule_expression: "cron(*/10 8 * * ? *)"
        schedule_expression_timezone: "America/Los_Angeles"

arc_runner_specs:
  dependabot:
    runner_size:
      max_runners: 100
      min_runners: 1
    scale_set_name: dependabot
    scale_set_type: dind
    container_actions_runner: 123456789012.dkr.ecr.us-east-1.amazonaws.com/actions-runner:latest
    container_requests_cpu: 500m
    container_requests_memory: 1Gi
    container_limits_cpu: '1'
    container_limits_memory: 2Gi
```

______________________________________________________________________

## 4. Deploy Secrets

1. **Navigate to the tenant directory** matching your AWS account, region, VPC, and tenant:

```bash
cd examples/deployments/forge-tenant/terragrunt/environments/<aws_account_alias>/regions/<aws_region>/vpcs/<vpc_alias>/tenants/<tenant_name>
```

2. **Deploy only the secrets** to AWS Secrets Manager:

```bash
terragrunt apply --target aws_secretsmanager_secret_version.cicd_secrets
```

> **Pro tip:** Use `--target` carefully — only apply secrets here to avoid accidental resource changes in other modules.

______________________________________________________________________

## 5. Create GitHub App

1. **Pull the registration UI container (amd64):**

```bash
docker pull ghcr.io/cisco-open/forge-forge-github-app-register:main
```

2. **Run it locally, exposing port 5000:**

```bash
docker run --rm -p 5000:5000 ghcr.io/cisco-open/forge-forge-github-app-register:main
```

3. **Open the UI:**

Go to `http://localhost:5000/` in your browser.

4. **In the UI:**

- Click **"Register App in Your Org"**
- Log in with your GitHub org or GHES admin account
- Use this pattern for the GitHub App name (replace variables):

```
${local.tenant_name}-${local.region_alias}-${local.vpc_alias}-${include.env.locals.runner_group_name_suffix}
```

Example:

```
sec-plat-euw1-shared-sbg-cicd-forge
```

- Click **“Create GitHub App”**

5. **After creation:**

- The app is created in your org or GHES instance.
- The UI will download the app config JSON containing critical secrets and keys.

### Tips:

- **Save the JSON file securely.** The private key (`pem`) in it is your authentication backbone. Lose it, and you start over.

- You **need** these values from the JSON (or GitHub later) to configure Forge’s secrets:

  - `client_id`
  - `id` (App ID)
  - `installation_id` (get it by installing the app on repos/org)
  - `pem` (private key)

- Permissions must be **exactly**:

  - `actions`: read
  - `checks`: read
  - `metadata`: read
  - `organization_self_hosted_runners`: write
  - `organization_administration`: write

- Subscribe the app to `"workflow_job"` event — this is how your runners get triggered.

- Don’t forget to install the GitHub App on the repositories or organizations that will use these runners.

______________________________________________________________________

## 6. Set GitHub App Secrets

Run the `update-github-app-secrets.sh` script to inject critical GitHub App values into your secrets:

```bash
./scripts/update-github-app-secrets.sh /full/path/to/tenant_dir client_id <GITHUB_APP_CLIENT_ID>
./scripts/update-github-app-secrets.sh /full/path/to/tenant_dir name <GITHUB_APP_NAME>
./scripts/update-github-app-secrets.sh /full/path/to/tenant_dir id <GITHUB_APP_ID>
./scripts/update-github-app-secrets.sh /full/path/to/tenant_dir key /path/to/private-key.pem
./scripts/update-github-app-secrets.sh /full/path/to/tenant_dir installation_id <GITHUB_APP_INSTALLATION_ID>
```

### Notes:

- Use **absolute paths** for tenant directories and private key files to avoid path resolution issues inside the script.
- Confirm the private key file has **correct permissions** (`chmod 600`) to avoid permission errors.
- The script will update AWS Secrets Manager values — verify with `terragrunt plan` or AWS Console if you want to double-check.

______________________________________________________________________

## 7. Deploy

1. **Navigate to your tenant directory:**

```bash
cd examples/deployments/forge-tenant/terragrunt/environments/<aws_account_alias>/regions/<aws_region>/vpcs/<vpc_alias>/tenants/<tenant_name>
```

2. **Deploy everything in one go:**

```bash
terragrunt apply
```

3. **Verify success:**

- No errors in Terraform apply output.
- All expected AWS resources exist.
- GitHub runners appear registered and are actively picking up jobs.

______________________________________________________________________

> For more advanced scenarios or troubleshooting, see the [full documentation](../index.md).
