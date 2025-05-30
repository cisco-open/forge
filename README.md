# Forge: Platform for Ephemeral EC2/EKS GitHub Runners with Tenant Isolation

[![Release](https://img.shields.io/github/v/release/cisco-open/forge?display_name=tag)](https://github.com/cisco-open/forge/releases/latest/)
[![License](https://img.shields.io/github/license/cisco-open/forge)](LICENSE.md)
[![Maintainer](https://img.shields.io/badge/Maintainer-Cisco-00bceb.svg)](https://opensource.cisco.com)

![CI](https://img.shields.io/github/check-runs/cisco-open/forge/main)
![Commits since latest release](https://img.shields.io/github/commits-since/cisco-open/forge/latest)
[![Contributors](https://img.shields.io/github/contributors/cisco-open/forge)](https://github.com/cisco-open/forge/graphs/contributors)

[![Contributor-Covenant](https://img.shields.io/badge/Contributor%20Covenant-1.4-fbab2c.svg)](CODE_OF_CONDUCT.md)

---

**Forge** is an open-source, production-grade platform that runs ephemeral GitHub Actions runners on AWS for multiple tenants — with built-in automation, security, and observability.

Built *by platform engineers, for platform engineers.*

**Why Forge?**
It empowers platform teams to deliver secure, cost-efficient, and scalable CI runners with minimal ongoing manual operations — and zero overhead for tenant teams.

> **Community-driven:**
> Forge is maintained on a best-effort basis. Contributions are welcome — triage issues, submit PRs, review code, or join the conversation!


## What Is Forge?

Forge is a control plane that automates the provisioning, isolation, and lifecycle of GitHub Actions runners — at scale. It combines two proven OSS projects:

* [`terraform-aws-github-runner`](https://github.com/github-aws-runners/terraform-aws-github-runner)
* [`actions-runner-controller`](https://github.com/actions/actions-runner-controller)

With added value:

* **Multi-tenant isolation**
* **Zero-touch automation**
* **Built-in observability**
* **Cost-efficient scheduling**


## Core Features

| Feature                    | Description                                       |
| -------------------------- | ------------------------------------------------- |
| **Ephemeral Runners**      | Auto-scaling EC2/EKS runners — zero idle costs    |
| **Tenant Isolation**       | IAM + OIDC + VPC boundaries per tenant            |
| **Zero-Touch Ops**         | Drift remediation, patching, upgrades, onboarding |
| **Built-in Observability** | Logs, metrics, dashboards                         |
| **Cost Optimization**      | Spot instances, scale-to-zero, warm pool logic    |
| **Customizable Infra**     | BYO AMIs, subnets, instance types                 |
| **Multi-Runner Support**   | Deploy multiple runner types in one module        |
| **Multi-OS**               | Linux (x64/arm64), Windows                        |
| **GitHub Cloud & GHES**    | Works across hosting models                       |


## Start from a Working Example

Use the starter config to bootstrap a new tenant:

→ [examples/starter-tenant]((https://github.com/cisco-open/forge/tree/main/examples/starter-tenant))

For detailed setup instructions, see  
→ [Using the Starter Tenant](./docs/configurations/using_starter_tenant.md)

## Architecture Overview

Forge glues together Tofu/Terraform, ARC, and native AWS constructs into a modular runner platform.

**Core Components:**

* [OpenTofu](https://opentofu.org/) or Terraform
* [Terragrunt](https://terragrunt.gruntwork.io/) (optional)
* [Helm](https://helm.sh/) for ARC
* AWS IAM + OIDC for secure runner registration
* VPC segmentation per tenant

**Platform Responsibilities:**

* Centralized provisioning
* Secure isolation between tenants
* Automated lifecycle + scaling logic
* GitHub App-based authorization
* Tenant-specific observability + access control


## How It Works

### Infrastructure Setup (One-Time)

1. Prepare an AWS account and IAM boundaries.
2. Deploy the Forge control plane using OpenTofu or Terraform.
3. Optionally use Terragrunt for layered configuration.

### Tenant Setup (Per Team)

1. Create a GitHub App.
2. Configure tenant module with desired runner types and settings.
3. Install the GitHub App into target orgs or repos.
4. Push workflows — Forge takes care of the rest.
5. Share the [Usage Guide](./docs/tenant-usage/) with your tenant

## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**. For detailed contributing guidelines, please see [CONTRIBUTING.md](CONTRIBUTING.md)

## Acknowledgements

Forge builds on the shoulders of giants in the open-source community. Special thanks to:

* [terraform-aws-github-runner](https://github.com/github-aws-runners/terraform-aws-github-runner)
* [actions-runner-controller](https://github.com/actions/actions-runner-controller)

## Further Reading

Want to understand how Forge scales, isolates tenants, and minimizes ops?

Check out the [technical case study](https://www.linkedin.com/pulse/forge-scalable-secure-multi-tenant-github-runner-brilhante--fyxbf) written by one of the core contributors.

## License

Distributed under the `Apache Software License`. See [LICENSE](LICENSE) for more information.

## Contact

For all project feedback, please use [Github Issues](https://github.com/cisco-open/forge/issues)
