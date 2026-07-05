# Repo: runner-base-image

Purpose: build the base AMIs used by Forge runner groups. Keep this repo focused
on OS updates, GitHub Actions runner prerequisites, Docker or CLI tooling, and
organization-wide agents. Put product-specific SDKs and language stacks in a
custom runner image repo that inherits from these AMIs.

```text
runner-base-image/
├── .github/workflows/build-image.yml
├── ansible/
│   ├── group_vars/all/common.yml
│   ├── playbooks/
│   │   ├── build_gh_runner.yml
│   │   ├── build_gh_runner_macos.yml
│   │   └── build_gh_runner_windows.yml
│   └── roles/deps/
├── packer/
│   ├── gha-runner.macos.pkr.hcl
│   ├── gha-runner.ubuntu.pkr.hcl
│   ├── gha-runner.windows.pkr.hcl
│   └── windows/
├── scripts/
└── renovate.json
```

Copy this folder as a repository root, then change these values first:

- `.github/workflows/build-image.yml`: runner label, AWS role, AWS region, VPC,
  subnet, and macOS dedicated-host settings.
- `packer/*.pkr.hcl`: `image_prefix`, `ami_regions`, `ami_users`,
  `ami_org_arns`, and `common_tags`.
- `ansible/group_vars/all/common.yml`: runner and tooling versions.
- `ansible/roles/deps/tasks/*.yml`: packages and agents you want on every base
  image.

Ubuntu builds use Canonical public AMIs, not private hardened image catalogs.
Windows builds use Amazon-published Microsoft Windows Server AMIs. macOS builds
use Amazon EC2 macOS AMIs and require a dedicated host resource group plus a
license configuration ARN.

This blueprint intentionally excludes organization-private CLIs and remote-access
agents. Add those back only if your organization needs them, and keep their CA,
endpoint, and enrollment settings in your private repo.

## Repository Variables

Create these GitHub repository variables:

| Variable                                 | Example                                                    | Notes                                                 |
| ---------------------------------------- | ---------------------------------------------------------- | ----------------------------------------------------- |
| `AWS_REGION`                             | `eu-west-1`                                                | Region where Packer runs.                             |
| `AWS_ROLE_TO_ASSUME`                     | `arn:aws:iam::123456789012:role/packer-runner-image-build` | OIDC role used by the workflow.                       |
| `PACKER_RUNNER_LABEL`                    | `ubuntu-latest` or `self-hosted`                           | Use a self-hosted runner if builders use private IPs. |
| `PACKER_VPC_ID`                          | `vpc-0123456789abcdef0`                                    | Builder VPC.                                          |
| `PACKER_SUBNET_ID`                       | `subnet-0123456789abcdef0`                                 | Builder subnet.                                       |
| `PACKER_ALLOWED_CIDR`                    | `10.0.0.0/8`                                               | CIDR allowed to reach SSH or WinRM during the build.  |
| `PACKER_MACOS_AVAILABILITY_ZONE`         | `us-west-2a`                                               | Required for macOS only.                              |
| `PACKER_MACOS_HOST_RESOURCE_GROUP_ARN`   | `arn:aws:resource-groups:...`                              | Required for macOS only.                              |
| `PACKER_MACOS_LICENSE_CONFIGURATION_ARN` | `arn:aws:license-manager:...`                              | Required for macOS only.                              |

Create `PACKER_GITHUB_API_TOKEN` as a secret if your builds hit GitHub release
rate limits while downloading runner packages.

## Build Flow

Pull requests run `packer init` and `packer validate` for each selected OS and
architecture. Pushes to `main`, manual runs, and the weekly schedule build AMIs
and upload `manifest.json` plus the Packer log.

The workflow supports these targets:

- Ubuntu 24.04: `amd64`, `arm64`
- Windows Server 2022: `amd64`
- macOS 14: `amd64`, `arm64`

Custom image repos should consume the resulting AMIs by name or tag. Do not copy
this base setup into every custom image repo.
