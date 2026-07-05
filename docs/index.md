# Forge Documentation

ForgeMT is a multi-tenant GitHub Actions runner platform for AWS. The open
source project uses ForgeMT as the searchable product name; the docs sometimes
use Forge as the short name. Platform teams use it to run ephemeral EC2 and
Kubernetes runners, onboard tenants, and keep runner infrastructure out of
application repos.

If you are new to Forge, read these pages first:

| Need                           | Page                                                  |
| ------------------------------ | ----------------------------------------------------- |
| Understand why Forge exists    | [Motivation](motivation.md)                           |
| Understand the platform shape  | [Architecture](architecture.md)                       |
| Install one working tenant     | [Minimal Install](getting-started/minimal-install.md) |
| Copy a real deployment example | [Examples](examples/index.md)                         |
| Review the security model      | [Security](security.md)                               |

The docs are organized by lifecycle:

| Stage   | Start here                                                  | Outcome                                                                  |
| ------- | ----------------------------------------------------------- | ------------------------------------------------------------------------ |
| Day 0   | [Bootstrap](getting-started/bootstrap.md)                   | Prepare AWS profile, backend, GitHub App, secrets, and runner image.     |
| Day 1   | [Configure Platform](getting-started/configure-platform.md) | Deploy one working Forge tenant, then add EKS, helpers, or integrations. |
| Day 2   | [Operations](operations/index.md)                           | Onboard tenants, manage images, rotate secrets, and troubleshoot jobs.   |
| Day 365 | [Upgrades](operations/upgrades.md)                          | Keep module refs, runner images, AMIs, ECR, and cleanup jobs maintained. |

## Platform Path

Deploy Forge in this order:

1. Prepare AWS, GitHub App, state backend, secrets, and runner images.
1. Use [Minimal Install](getting-started/minimal-install.md) to prove one
   tenant runner lane before adding more categories.
1. Configure [helpers](getting-started/configure-helpers.md) only when your
   account needs region opt-in, service-linked roles, AMI sharing, ECR, storage,
   or cleanup jobs.
1. Configure [infra](getting-started/configure-infra.md) only when Forge owns
   the EKS foundation for ARC runners.
1. Configure [platform](getting-started/configure-platform.md) to deploy one
   tenant and prove runner registration.
1. Configure [integrations](getting-started/configure-integrations.md) only for
   systems your company actually uses.

## Optional Integrations

Splunk, Teleport, OpenTelemetry, OpenCost, webhook relay destination modules,
and vendor-specific dashboards are optional. If your company does not use one of
those systems, skip its example folder, module family, and secrets.

Use [Integrations](integrations/index.md) only after the platform runner path is
working.

## Tenant Path

Tenant teams do not deploy Forge. They use the runner labels, GitHub App
installation, and AWS access model provided by the platform team. Start with
[Tenant Usage](tenant-usage/index.md).
