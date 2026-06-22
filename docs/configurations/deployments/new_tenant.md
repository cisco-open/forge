# Deploy a New Tenant

This checklist tells you *exactly* what to update to onboard a new Forge tenant.

______________________________________________________________________

## 1. Create Tenant Config Files

Copy these templates and place them at the correct paths.

### Templates to Copy

- `examples/templates/tenant/_global_settings/tenant.hcl`
- `examples/templates/tenant/tenant/terragrunt.hcl`
- `examples/templates/tenant/tenant/runner_settings.hcl`
- `examples/templates/tenant/tenant/config.yml`

### Destination Paths

```
examples/deployments/forge-tenant/terragrunt/_global_settings/tenants/<tenant_name>.hcl

examples/deployments/forge-tenant/terragrunt/environments/<aws_account>/regions/<aws_region>/vpcs/<vpc_alias>/tenants/<tenant_name>/terragrunt.hcl

examples/deployments/forge-tenant/terragrunt/environments/<aws_account>/regions/<aws_region>/vpcs/<vpc_alias>/tenants/<tenant_name>/runner_settings.hcl

examples/deployments/forge-tenant/terragrunt/environments/<aws_account>/regions/<aws_region>/vpcs/<vpc_alias>/tenants/<tenant_name>/config.yml
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

cp examples/templates/tenant/tenant/config.yml \
   examples/deployments/forge-tenant/terragrunt/environments/sec-plat/regions/eu-west-1/vpcs/shared/tenants/sbg/config.yml
```

______________________________________________________________________

## 2. Edit `config.yml` — Tenant Configuration Fields

Controls GitHub integration, IAM roles, EC2-wide runner settings, and runner specs (EC2 & ARC).

______________________________________________________________________

### Top-level Structure & Key Fields

```yaml
gh_config:
  ghes_url: <GITHUB_URL>              # Empty string for github.com, full GHES URL otherwise
  ghes_org: <GITHUB_ORG>              # Exact GitHub organization name
  repository_selection: <repository_selection> # Type of repository selection (all or selected)
  github_webhook_relay:               # (Optional) Forward incoming GitHub webhook events cross-account via EventBridge
    enabled: false                    # Set true to forward events to another account/region
    destination_account_id: ""       # Target AWS account ID owning the destination EventBridge bus
    destination_event_bus_name: ""    # Destination EventBridge bus name (blank => default bus when supported)
    destination_region: ""            # Destination AWS region for the forwarding rule
    destination_reader_role_arn: ""   # IAM role in destination allowed to read forwarded events (leave blank if not needed)
    # NOTE: Leave all destination_* fields blank when enabled=false; they are ignored.
  github_app:
    id: <GITHUB_APP_ID>                          # Numeric GitHub App ID from GitHub settings
    client_id: <GITHUB_APP_CLIENT_ID>            # OAuth client ID shown on the GitHub App page
    installation_id: <GITHUB_APP_INSTALLATION_ID> # Installation ID after installing the app in your org/account
    name: <GITHUB_APP_NAME>                      # Exact GitHub App name (must match the created app)

tenant:
  iam_roles_to_assume:                # List of full AWS IAM role ARNs runners may assume for workloads
    - arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME>
  ecr_registries:                     # Allowed ECR repo URLs (full), e.g. 123456789012.dkr.ecr.us-east-1.amazonaws.com
    - <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com
  github_logs_reader_role_arns:       # (Optional) IAM role ARNs granted read (+ KMS decrypt) access to archived GitHub job/workflow logs
    - arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME>

ec2_config:
  enable_dynamic_labels: <true|false>  # Enable dynamic ghr-* labels for EC2 runners

ec2_runner_specs:
  <runner_type-alias>:               # e.g. small, medium, gpu, mac
    type: <runner_type>              # Runner type label advertised to GitHub
    ami_name: <AMI_NAME_PATTERN>     # AMI name pattern, supports wildcard *, e.g. forge-gh-runner-v*
    ami_owner: <ACCOUNT_ID>          # AWS account ID owning AMI
    ami_kms_key_arn: <KMS_ARN>       # Set to '' if AMI is unencrypted, else KMS ARN string
    runner_os: <OS>                  # linux, osx, or windows
    runner_architecture: <ARCH>      # x64 or arm64
    runner_user: <RUNNER_USER>       # OS user that runs the GitHub runner process
    placement:                       # Required for macOS dedicated-host runners; omit otherwise
      host_resource_group_arn: <HOST_RESOURCE_GROUP_ARN>
      tenancy: host
      availability_zone: <AVAILABILITY_ZONE>
    max_instances: <MAX_PARALLEL>    # Max EC2 runners allowed in parallel
    license_specifications: <LICENSE_SPECIFICATIONS> # Optional License Manager config for dedicated hosts
    use_dedicated_host: <true|false> # Set true for macOS EC2 runners
    vpc_id: <VPC_ID>                 # Optional override; defaults to tenant VPC when omitted
    subnet_ids:                      # Optional override; defaults to tenant subnets when omitted
      - <SUBNET_ID>
    instance_types:                  # List of allowed instance types
      - <AWS_INSTANCE_TYPE>          # e.g. t3.large, m5.large, mac2.metal
    pool_config:                     # Warm pool config for pre-warming runners; empty list [] disables
      - size: <POOL_SIZE>            # Number of instances to keep warm
        schedule_expression: <AWS_CRON_EXPR>  # AWS cron expression (6 fields, use AWS docs)
        schedule_expression_timezone: <TIMEZONE>  # Optional timezone, e.g. UTC, America/New_York
    volume:
      size: <VOLUME_SIZE>
      device_name: <VOLUME_DEVICE_NAME>
      iops: <VOLUME_IOPS>
      throughput: <VOLUME_THROUGHPUT>
      type: <VOLUME_TYPE>

arc_runner_specs:
  <runner_type>:                    # e.g. dependabot, k8s
    runner_size:
      max_runners: <MAX>            # Max pods/runners (Max Pod allowed in parallel)
      min_runners: <MIN>            # Min pods/runners (warm pool)
    scale_set_name: <NAME>          # Used for ARC annotations and scale set identification
    scale_set_type: <dind|k8s>      # Must be exactly 'dind' or 'k8s', no other values allowed
    scale_set_labels:               # GitHub runner labels advertised by this ARC scale set
      - <LABEL>                     # e.g. dependabot, k8s, dind
    container_images:               # Optional image overrides; omit fields to use module defaults
      actions_runner: ghcr.io/actions/actions-runner:latest
      busybox: public.ecr.aws/docker/library/busybox:stable
      dind_rootless: public.ecr.aws/docker/library/docker:dind-rootless
    container_requests_cpu: <CPU>   # Kubernetes CPU requests, e.g. 500m (mandatory unit)
    container_requests_memory: <MEM> # Kubernetes memory requests, e.g. 1Gi (mandatory unit)
    container_limits_cpu: <CPU>     # Kubernetes CPU limits
    container_limits_memory: <MEM>  # Kubernetes memory limits
    volume_requests_storage_type: <STORAGE_TYPE> # Storage class/type for runner workspace volume
    volume_requests_storage_size: <STORAGE_SIZE> # Size for runner workspace volume

arc_cluster_name: <CLUSTER_NAME>
migrate_arc_cluster: <true|false>

```

______________________________________________________________________

### Field Guidance & Gotchas

- **`ghes_url`**: empty for github.com, full URL for GHES.
- **`repository_selection`**: use `all` or `selected`, matching the GitHub App installation scope.
- **`iam_roles_to_assume`**: full ARNs only, no wildcards.
- **`ecr_registries`**: must be full URLs, including account and region.
- **`github_logs_reader_role_arns`**:
  - Provide a list of IAM Role ARNs that need read (and KMS decrypt) access to archived GitHub job/workflow logs.
  - Leave the list empty (or omit) if no external roles should access logs.
  - Roles are added to the S3 bucket policy (GetObject/ListBucket) and KMS key policy (Decrypt/Describe/GenerateDataKey\*).
  - Avoid granting organization-wide wildcard roles; principle of least privilege.
- **`ec2_config.enable_dynamic_labels`**: set to `true` to allow EC2 jobs to use dynamic `ghr-` labels, such as labels that override EC2 runtime options or add dynamic runner labels. Keep `false` unless the tenant needs this behavior.
- **`type`**: logical EC2 runner type used in generated GitHub labels.
- **`ami_kms_key_arn`**: must be explicitly set to `''` if AMI not encrypted; otherwise runner fails.
- **`runner_os`**: set the operating system for the runner AMI, for example `linux`, `osx`, or `windows`.
- **`runner_architecture`**: set the runner CPU architecture, for example `x64` or `arm64`.
- **`runner_user`**: OS user that runs the GitHub runner process on the EC2 instance.
- **`max_instances`**: check AWS EC2 quota before setting.
- **`vpc_id` / `subnet_ids`**: optional per-runner network overrides. Omit them to use the tenant-level VPC and subnets.
- **`instance_types`**: spot-compatible preferred for cost savings.
- **`volume`**: root volume settings for the runner AMI, including size, device name, IOPS, throughput, and EBS type.
- **`use_dedicated_host`**: set to `true` for macOS EC2 runners, because Mac instances require EC2 Dedicated Hosts. Pair it with `placement.tenancy: host`, a host resource group or host ID, and an availability zone that has matching Mac host capacity.
- **`license_specifications`**: include License Manager configuration ARNs when your dedicated host resource group requires them for macOS runners.
- **`pool_config.schedule_expression`**: AWS cron syntax with 6 fields, **not** standard cron. Example: `cron(0 8 * * ? *)`. See [AWS docs](https://docs.aws.amazon.com/eventbridge/latest/userguide/scheduled-events.html#cron-expressions).
- **`scale_set_type`**: only `dind` or `k8s`. Wrong values cause runtime errors.
- **`scale_set_labels`**: labels used in workflow `runs-on` matching for ARC runners. Include at least the intended runner type label.
- **`volume_requests_storage_type` / `volume_requests_storage_size`**: storage class/type and size used for ARC runner workspace volumes.
- **`arc_cluster_name`**: EKS cluster where ARC runners are deployed.
- **`migrate_arc_cluster`**: set to `true` only for an intentional ARC cluster migration flow; otherwise keep `false`.
- **Kubernetes CPU/memory fields**: units mandatory (e.g., `500m`, `1Gi`). Missing units break pods.

#### `github_webhook_relay` Guidance

- Set `enabled: true` only when you need to forward GitHub webhook events (e.g., `workflow_job`) to a central or cross-account EventBridge bus.
- When enabled, you must supply at least `destination_account_id` and usually `destination_region`.
- `destination_event_bus_name`: Leave blank to target the default bus; specify to use a custom bus.
- `destination_reader_role_arn`: Provide if a specific role in the destination account needs read access for diagnostics/metrics; leave blank otherwise.
- All `destination_*` keys are ignored when `enabled: false` (can be left as placeholders).
- Typical use cases: central analytics, multi-account runner orchestration, or security event aggregation.

#### macOS EC2 Runner Guidance

macOS runners must run on EC2 Dedicated Hosts. Configure the runner spec with `use_dedicated_host: true`, host placement, and Mac instance types:

```yaml
ec2_runner_specs:
  mac:
    type: mac
    ami_name: forge-gh-runner-macarm-v*
    ami_owner: '123456789012'
    ami_kms_key_arn: ''
    runner_os: osx
    runner_architecture: arm64
    runner_user: ec2-user
    placement:
      host_resource_group_arn: arn:aws:resource-groups:<REGION>:<ACCOUNT_ID>:group/<HOST_RESOURCE_GROUP>
      tenancy: host
      availability_zone: <AVAILABILITY_ZONE>
    license_specifications:
      - license_configuration_arn: arn:aws:license-manager:<REGION>:<ACCOUNT_ID>:license-configuration:<LICENSE_CONFIGURATION_ID>
    use_dedicated_host: true
    vpc_id: <VPC_ID>
    subnet_ids:
      - <SUBNET_ID>
    max_instances: <MAX_PARALLEL>
    instance_types:
      - mac2.metal
    pool_config: []
    volume:
      size: <VOLUME_SIZE>
      device_name: <VOLUME_DEVICE_NAME>
      iops: <VOLUME_IOPS>
      throughput: <VOLUME_THROUGHPUT>
      type: gp3
```

Use a subnet in the same availability zone as the dedicated host placement. If your host resource group does not require License Manager, omit `license_specifications`.

______________________________________________________________________

### Common Pitfalls — Avoid These

- Wildcard or invalid IAM roles → runner startup failures.
- Forgetting `ami_kms_key_arn` = `''` when AMI isn’t encrypted → Terraform errors.
- Setting up macOS runners without `use_dedicated_host: true` or matching host placement → EC2 launch failures.
- Incorrect cron syntax → scheduled warm pools don’t trigger.
- Setting max runners beyond quotas → failures or throttling.
- Missing units in k8s resource requests/limits → pod rejection.

______________________________________________________________________

## 3. Create GitHub App

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

## 4. Minimal Working `config.yml` Example

```yaml
gh_config:
  ghes_url: ''
  ghes_org: cisco-sbg
  repository_selection: selected
  github_webhook_relay:  
    enabled: false
    destination_account_id: ""
    destination_event_bus_name: ""
    destination_region: ""
    destination_reader_role_arn: ""
  github_app:
    id: 1234567890
    client_id: abcdefghijklmnopqrstuvwx
    installation_id: 9876543210
    name: forge-github-app

tenant:
  iam_roles_to_assume:
    - arn:aws:iam::123456789012:role/role_for_forge_runners
  ecr_registries:
    - 123456789012.dkr.ecr.us-east-1.amazonaws.com
  github_logs_reader_role_arns:
    - arn:aws:iam::123456789012:role/github_logs_reader

ec2_config:
  enable_dynamic_labels: false

ec2_runner_specs:
  small:
    type: small
    ami_name: forge-gh-runner-v*
    ami_owner: '123456789012'
    ami_kms_key_arn: ''
    runner_os: linux
    runner_architecture: x64
    runner_user: ubuntu
    max_instances: 10
    vpc_id: vpc-0abc1234def567890
    subnet_ids:
      - subnet-0abc1234def567890
    instance_types:
      - t3.small
      - t3.medium
    pool_config:
      - size: 2
        schedule_expression: "cron(*/10 8 * * ? *)"
        schedule_expression_timezone: "America/Los_Angeles"
    volume:
      size: 200
      device_name: /dev/sda1
      iops: 3000
      throughput: 125
      type: gp3

arc_runner_specs:
  dependabot:
    runner_size:
      max_runners: 100
      min_runners: 1
    scale_set_name: dependabot
    scale_set_type: dind
    scale_set_labels:
      - dependabot
      - dind
    container_images:
      actions_runner: ghcr.io/actions/actions-runner:latest
      busybox: public.ecr.aws/docker/library/busybox:stable
      dind_rootless: public.ecr.aws/docker/library/docker:dind-rootless
    container_requests_cpu: 500m
    container_requests_memory: 1Gi
    container_limits_cpu: '1'
    container_limits_memory: 2Gi
    volume_requests_storage_type: gp2
    volume_requests_storage_size: 10Gi

arc_cluster_name: forge-arc-cluster
migrate_arc_cluster: false
```

______________________________________________________________________

## 5. Deploy

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

______________________________________________________________________

## 6. Set GitHub App Secrets

Run the `update-github-app-secrets.sh` script to inject critical GitHub App values into your secrets:

```bash
./scripts/update-github-app-secrets.sh /full/path/to/tenant_dir /path/to/private-key.pem
```

### Notes:

- Use **absolute paths** for tenant directories and private key files to avoid path resolution issues inside the script.
- Confirm the private key file has **correct permissions** (`chmod 600`) to avoid permission errors.
- The script will update AWS SSM Parameter values — verify with `terragrunt plan` or AWS Console if you want to double-check.

______________________________________________________________________

## 7. Redeploy with secrets updated

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

> For more advanced scenarios or troubleshooting, see the [full documentation](../index.md).
