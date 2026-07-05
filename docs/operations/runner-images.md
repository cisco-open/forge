# Runner Images

Forge EC2 runners depend on AMIs. ARC runners depend on container images. Treat
both as platform artifacts with versioned releases and rollback paths.

## Base Image

Use a base image repo when you need consistent Linux, Windows, or macOS runner
AMIs. The supported copyable blueprint is:

```text
docs/operations/repo-blueprints/runner-base-image
```

Keep base images generic:

- GitHub Actions runner prerequisites
- Docker or container tooling when needed
- cloud CLIs used by most tenants
- security baseline and patching

Do not bake tenant secrets, company-only endpoints, or access tokens into AMIs.

The blueprint includes:

- Ubuntu 24.04 builds for `amd64` and `arm64`
- Windows Server 2022 builds for `amd64`
- macOS 14 builds for `amd64` and `arm64`
- Ansible playbooks under `ansible/playbooks`
- a GitHub workflow that validates PRs and can build AMIs manually or weekly

Set these environment variables before a local Ubuntu build:

| Variable              | Meaning                                                       |
| --------------------- | ------------------------------------------------------------- |
| `AWS_REGION`          | Region where the AMI is built.                                |
| `PACKER_VPC_ID`       | VPC where Packer launches the temporary builder instance.     |
| `PACKER_SUBNET_ID`    | Subnet for the builder instance. It must be reachable by SSH. |
| `PACKER_ALLOWED_CIDR` | CIDR allowed to reach the builder instance during the build.  |
| `AMI_ARCH`            | `amd64` or `arm64`.                                           |
| `UBUNTU_VERSION`      | `24.04` for the default Canonical Ubuntu build.               |
| `VERSION`             | AMI version suffix.                                           |
| `BRANCH`              | Source branch tag for traceability.                           |
| `JOB_ID`              | CI job ID or `manual` for local builds.                       |

Local build:

```bash
cd docs/operations/repo-blueprints/runner-base-image
export AWS_REGION=eu-west-1
export PACKER_VPC_ID=vpc-0123456789abcdef0
export PACKER_SUBNET_ID=subnet-0123456789abcdef0
export PACKER_ALLOWED_CIDR=10.0.0.0/8
export AMI_ARCH=amd64
export UBUNTU_VERSION=24.04
export VERSION=manual-$(date +%Y%m%d%H%M%S)
export BRANCH=$(git rev-parse --abbrev-ref HEAD)
export JOB_ID=manual

packer init packer/gha-runner.ubuntu.pkr.hcl
packer validate packer/gha-runner.ubuntu.pkr.hcl
packer build \
  packer/gha-runner.ubuntu.pkr.hcl
```

The generated AMI name is:

```text
forge-runner-base-ubuntu2404-<arch>-<version>
```

Use that pattern in tenant runner settings:

```yaml
ec2_runner_specs:
  small:
    ami_name: forge-runner-base-ubuntu2404-amd64-*
    ami_owner: '123456789012'
```

## Custom Image

Use a custom image repo when a tenant or workload needs additional tools on top
of the base image:

```text
docs/operations/repo-blueprints/runner-custom-image
```

The output should be a new AMI name or image version that can be referenced in
tenant `config.yml`.

## Release Flow

1. Build the image with Packer.
1. Run a workflow smoke test on the AMI.
1. Share the AMI if runners consume it from another account.
1. Update tenant runner specs.
1. Keep the previous AMI available until the tenant smoke test passes.

## Validation

Before using the AMI in a tenant:

1. Confirm the AMI is available in the same account or shared to the tenant
   account.
1. Confirm the AMI architecture matches `runner_architecture`.
1. Confirm `runner_user` matches the user configured in the image.
1. Confirm encrypted AMIs include the right `ami_kms_key_arn`, or set it to an
   empty string for unencrypted AMIs.
