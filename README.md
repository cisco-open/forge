# 🚀 Forge CI Platform

**Forge** is a scalable, secure, and fully automated **multi-tenant** platform for running **ephemeral GitHub Actions runners on AWS** — designed for platform teams, by platform engineers.

> 🛠️ **Community-Driven:**
> Forge is an open-source project maintained on a best-effort basis. Contributions are welcome — help triage issues, submit PRs, review code, or join discussions!

📚 **Docs:**
Comprehensive documentation is available at [cisco-open.github.io/forge](https://cisco-open.github.io/forge/).

## 🔍 What Is Forge?

Forge automates the provisioning and lifecycle management of ephemeral GitHub Actions runners across EC2 and EKS, leveraging the [terraform-aws-github-runner](https://github.com/github-aws-runners/terraform-aws-github-runner) module and [actions-runner-controller](https://github.com/actions/actions-runner-controller) Helm chart — adding multi-tenant isolation, drift remediation, and native observability out-of-the-box.

### 🔑 Core Features

* **Ephemeral Runners:** Auto-scaling EC2 and EKS runners — zero idle waste.
* **Tenant Isolation:** Secure per-tenant boundaries using IAM and OIDC.
* **Zero-Touch Automation:** Fully automated lifecycle — patching, updates, drift detection, onboarding.
* **Observability Built-In:** Dashboards, logs, and metrics out-of-the-box.
* **Cost-Aware Scheduling:** Spot instances + scale-to-zero = minimal cost.
* **Flexible Infrastructure:** BYO AMI, instance types, subnets, and more.
* **Multi-Runner Deployments:** Launch multiple runner types in one deployment.
* **Broad OS Support:** Linux (x64/arm64) and Windows.
* **GitHub Cloud & GHES Support:** Seamless support for both hosting models.

## ⚡ Getting Started

Start fast with our [Getting Started guide](./docs/configurations/).

### 🏗️ Infrastructure Setup

1. Prepare your AWS account.
2. Deploy the Forge infrastructure and platform modules using [Tofu](https://opentofu.org/) — optionally with [Terragrunt](https://terragrunt.gruntwork.io/) for layered configuration and environment management.

### 🧩 Tenant Configuration

1. Create and configure a GitHub App with the required permissions.
2. Deploy the tenant configuration using Tofu (and optionally Terragrunt).
3. Install the GitHub App in the target GitHub organization or repositories.
4. Assign repositories to the appropriate runner group(s).

💡 Need deployment examples? Check the [examples directory](./examples).


## 🔑 Tenant Usage & Onboarding

Ready to start running workflows with Forge? Check out the **Forge Tenant Usage Guide** — a practical, step-by-step resource to get your team’s GitHub repositories connected to Forge runners, configure runner types, and manage advanced options like AWS access and containerized jobs.

[Go to Forge Tenant Usage Guide →](./docs/tenant-usage/)


## ⚙️ Configuration

Tweak every part of Forge to your needs — from AMIs and subnet choices to concurrency settings.
See the [Configuration Docs](./docs/configurations/) for details and best practices.

## 🧭 Roadmap

Want to see what’s next or request features? Check the [open issues](https://github.com/cisco-open/forge/issues).


## 🙌 Acknowledgements

Forge builds on the shoulders of giants in the open-source community. Special thanks to:

* [terraform-aws-github-runner](https://github.com/github-aws-runners/terraform-aws-github-runner) ⚙️
* [actions-runner-controller](https://github.com/actions/actions-runner-controller) 🚀

## 🤝 Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**. For detailed contributing guidelines, please see [CONTRIBUTING.md](CONTRIBUTING.md) ✍️

## 📜 License

Distributed under the `Apache Software License`. See [LICENSE](LICENSE) for more information.

## 📬 Contact

For all project feedback, please use [Github Issues](https://github.com/cisco-open/forge/issues) 💬
