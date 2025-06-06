# ForgeMT: Ephemeral GitHub Runners with Secure Multi-Tenant Isolation

[![Release](https://img.shields.io/github/v/release/cisco-open/forge?display_name=tag)](https://github.com/cisco-open/forge/releases/latest/)
[![License](https://img.shields.io/github/license/cisco-open/forge)](LICENSE.md)
[![Maintainer](https://img.shields.io/badge/Maintainer-Cisco-00bceb.svg)](https://opensource.cisco.com)
![CI](https://img.shields.io/github/check-runs/cisco-open/forge/main)
![Commits since latest release](https://img.shields.io/github/commits-since/cisco-open/forge/latest)
[![Contributors](https://img.shields.io/github/contributors/cisco-open/forge)](https://github.com/cisco-open/forge/graphs/contributors)
[![Contributor-Covenant](https://img.shields.io/badge/Contributor%20Covenant-1.4-fbab2c.svg)](CODE_OF_CONDUCT.md)

---

**ForgeMT** is a production-grade platform for running secure, ephemeral GitHub Actions runners on AWS with strict multi-tenant isolation, cost-optimization, and observability built in.

Designed for platform teams delivering CI/CD at scale.

---

## Quick Start

- **[Deploy Your First Tenant](./docs/configurations/deployments/forge_tenant.md)**  
  Minimal setup for bootstrapping ForgeMT.

- **[All Deployment Scenarios](./docs/configurations/deployments/index.md)**  
  Includes Splunk, EKS, BYO AMIs, and advanced patterns.

- **[Tenant Usage Guide](./docs/tenant-usage/index.md)**  
  Covers onboarding, GitHub App setup, and day-2 operations.

---

## Why ForgeMT?

Traditional CI infrastructure is often:
- Expensive due to idle runners
- Hard to scale and operate
- Insecure across teams
- Difficult to monitor

**ForgeMT solves these problems:**
- Isolates tenants using IAM, OIDC, and VPC segmentation
- Automates runner lifecycle and scaling
- Integrates with GitHub Apps for secure access
- Centralizes observability per tenant
- Minimizes costs with spot instances and scale-to-zero

---

## Core Features

| Feature                    | Description                                       |
| -------------------------- | ------------------------------------------------- |
| Ephemeral Runners          | Auto-scaling EC2 or EKS runners with no idle cost |
| Tenant Isolation           | Secure IAM + OIDC + VPC per team or project       |
| Zero-Touch Operations      | Automatic patching, drift remediation, upgrades   |
| Built-in Observability     | Logs, metrics, dashboards by tenant               |
| Cost Optimization          | Spot instances, scale-to-zero, warm pool support  |
| Flexible Infrastructure    | BYO AMIs, VPCs, subnets, instance types           |
| Multi-Runner Support       | Mix EC2 and EKS runners in one deployment         |
| GitHub Cloud and GHES      | Works with SaaS and on-prem GitHub setups         |

---

## How ForgeMT Works

1. **Platform Setup:**  
   Deploy the ForgeMT control plane using OpenTofu or Terraform.  
   Define IAM roles, OIDC trust, and VPC segmentation.  
   Optionally manage configurations with Terragrunt.

2. **Tenant Onboarding:**  
   Create a GitHub App for each tenant.  
   Define a tenant module configuration with desired runner settings.  
   Install the GitHub App into the appropriate GitHub org or repos.  
   Push GitHub workflows — ForgeMT provisions and scales runners automatically.

- See the [Tenant Usage Guide](./docs/tenant-usage/index.md) for full details.

---

## Deployment Examples

- **[Deploy Your First Tenant](./docs/configurations/deployments/forge_tenant.md)** — Minimal setup to get started.
- **[All Deployment Scenarios](./docs/configurations/deployments/index.md)** — EKS, Splunk, integrations, and more.

---

## Architecture Overview

ForgeMT coordinates GitHub runner infrastructure with:

- **OpenTofu** or **Terraform** for infrastructure as code
- **Terragrunt** for environment layering (optional)
- **Helm** for deploying ARC (actions-runner-controller)
- **AWS IAM**, **OIDC**, **VPCs** for isolation and security
- **GitHub Apps** for scoped access per tenant

ForgeMT responsibilities include:

- Centralized provisioning of runners
- Secure tenant-level boundaries
- Auto-scaling and lifecycle management
- Per-tenant observability and access control

---

## Learn More

- [Technical Case Study](https://www.linkedin.com/pulse/forge-scalable-secure-multi-tenant-github-runner-brilhante--fyxbf)
- [Full Documentation](./docs/configurations/index.md)

---

## Contributing

We welcome contributions of all kinds. You can submit issues, pull requests, and suggestions.

See [CONTRIBUTING.md](CONTRIBUTING.md) for full guidelines.

---

## Acknowledgements

ForgeMT builds on the work of:

- [terraform-aws-github-runner](https://github.com/github-aws-runners/terraform-aws-github-runner)
- [actions-runner-controller](https://github.com/actions/actions-runner-controller)

---

## License

Apache 2.0 License — see [LICENSE](LICENSE) for details.

---

## Contact

Open issues and track progress on GitHub:  
[https://github.com/cisco-open/forge/issues](https://github.com/cisco-open/forge/issues)
