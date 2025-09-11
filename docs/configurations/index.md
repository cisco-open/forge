# ForgeMT Configuration

This guide helps you navigate ForgeMT configuration modules—from platform setup to integrations. Follow it to deploy ForgeMT correctly, understand module dependencies, and onboard tenant teams with clarity.

______________________________________________________________________

## Quick Start

Start here if you're deploying for the first time:

- 1. [First Tenant Deployment](./deployments/new_tenant.md)
- 2. [Build GitHub Actions Base Image](./build/gh_base_image.md)
- 3. [EKS Deployment Example](./deployments/forge_eks.md)
- 4. [Splunk Integration Example](./deployments/splunk_deployment.md)
- 5. [Secrets Reference](./secrets.md)
- 6. [Module Dependency Guide](./dependency.md)

______________________________________________________________________

## Core Components

### Control Plane (Platform-Owned)

| Module                    | Description                                                   |
| ------------------------- | ------------------------------------------------------------- |
| `platform/forge_runners`  | Top-level module. Provisions runners and wires EC2/EKS logic. |
| `platform/ec2_deployment` | Sets up EC2-based ephemeral runners.                          |
| `platform/arc_deployment` | Sets up EKS runners using actions-runner-controller.          |

______________________________________________________________________

## Infrastructure Modules

Used to create AWS primitives required by ForgeMT.

### Core Infrastructure

| Module                       | Purpose                                  |
| ---------------------------- | ---------------------------------------- |
| `infra/eks`                  | Provisions EKS cluster for ARC           |
| `infra/ecr`                  | Creates ECR repos for runner images      |
| `infra/storage`              | Creates S3 buckets for logs and metadata |
| `infra/ami_policy`           | Grants permissions to use shared AMIs    |
| `infra/ami_sharing`          | Shares AMIs across regions/accounts      |
| `infra/opt_in_regions`       | Enables additional AWS regions           |
| `infra/service_linked_roles` | Enables EC2 Spot functionality           |

### Cost & Policy Management

| Module                  | Purpose                          |
| ----------------------- | -------------------------------- |
| `infra/budget`          | Creates AWS budget alerts        |
| `infra/billing`         | Adds CloudWatch billing alarms   |
| `infra/cloud_custodian` | Applies cleanup/governance rules |

______________________________________________________________________

## Integrations

Optional modules for observability, access, and compliance.

| Module                  | Notes                                                |
| ----------------------- | ---------------------------------------------------- |
| `integrations/splunk_*` | Set of modules for Splunk Cloud, secrets, dashboards |
| `integrations/teleport` | Enables audit/session capture via Teleport           |

______________________________________________________________________

## Secrets and Identity

| Item                                | Purpose                                  |
| ----------------------------------- | ---------------------------------------- |
| [Secrets Reference](./secrets.md)   | Documents required keys, formats, scopes |
| [Dependency Guide](./dependency.md) | Shows setup order across modules         |

______________________________________________________________________

## Deployment & Build Scenarios

Ready-made configuration examples:

- [First Tenant Deployment](./deployments/new_tenant.md)
- [Build GitHub Actions Base Image](./build/gh_base_image.md)
- [EKS Deployment Example](./deployments/forge_eks.md)
- [Splunk Integration Example](./deployments/splunk_deployment.md)

View all: [Deployment Index](./deployments/index.md)

______________________________________________________________________

## Recommended Setup Order

- 1. Build the GitHub Actions base image ([guide](./build/gh_base_image.md))
- 2. Deploy base `infra/` modules (VPCs, EKS, IAM, S3, etc.)
- 3. Deploy `platform/forge_runners`
- 4. Configure secrets and tenant GitHub Apps
- 5. Enable integrations (e.g., Splunk, Teleport)

______________________________________________________________________
