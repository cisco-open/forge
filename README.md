# Forge CICD

## About ForgeMT
ForgeMT is a centralized, multi-tenant GitHub Actions runner platform built to help engineering teams scale their CI/CD pipelines securely and efficiently. By providing ephemeral runners on EC2 or Kubernetes (EKS), ForgeMT eliminates the need for teams to maintain their own CI infrastructure, reducing overhead, improving security, and accelerating onboarding.

Key features of ForgeMT include:

Ephemeral Runners: EC2 and EKS-based runners that automatically scale and terminate as needed.

Strict Tenant Isolation: Each team operates in its own secure environment with IAM/OIDC-based access controls.

Full Automation: End-to-end CI lifecycle management including patching, Terraform drift detection, and repository onboarding.

Built-in Observability: Integrated metrics, logs, and dashboards for complete visibility.

ForgeMT provides a unified control plane to consolidate fragmented CI environments into a secure, scalable platform that reduces operational overhead and enhances collaboration across teams.


## Getting Started

To get a local copy up and running follow these simple steps.


### Installation

1. Clone the repo

   ```sh
   git clone https://github.com/cisco-open/forge.git
   ```

## Roadmap

See the [open issues](https://github.com/cisco-open/forge/issues) for a list of proposed features (and known issues).

## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**. For detailed contributing guidelines, please see [CONTRIBUTING.md](CONTRIBUTING.md)

## License

Distributed under the `Apache Software License` License. See [LICENSE](LICENSE) for more information.

## Contact

For all project feedback, please use [Github Issues](https://github.com/cisco-open/forge/issues).
