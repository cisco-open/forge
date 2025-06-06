# ForgeMT Configuration

This guide helps you navigate ForgeMT configuration modules—from platform setup to integrations. Follow it to deploy ForgeMT correctly, understand module dependencies, and onboard tenant teams with clarity.

---

## Quick Start

Start here if you're deploying for the first time:

1. [First Tenant Deployment](./deployments/forge_tenant.md)
2. [Tenant Usage Guide](../tenant-usage/index.md)
3. [Secrets Reference](./secrets.md)
4. [Module Dependency Guide](./dependency.md)

---

## Core Components

### Control Plane (Platform-Owned)

| Module                    | Description                                          |
|---------------------------|------------------------------------------------------|
| `platform/forge_runners`  | Top-level module. Provisions runners and wires EC2/EKS logic. |
| `platform/ec2_deployment` | Sets up EC2-based ephemeral runners.                |
| `platform/arc_deployment` | Sets up EKS runners using actions-runner-controller. |

---

## Infrastructure Modules

Used to create AWS primitives required by ForgeMT.

### Core Infrastructure

| Module                    | Purpose                                    |
|---------------------------|--------------------------------------------|
| `infra/eks`               | Provisions EKS cluster for ARC             |
| `infra/ecr`               | Creates ECR repos for runner images        |
| `infra/storage`           | Creates S3 buckets for logs and metadata   |
| `infra/ami_policy`        | Grants permissions to use shared AMIs      |
| `infra/ami_sharing`       | Shares AMIs across regions/accounts        |
| `infra/opt_in_regions`    | Enables additional AWS regions             |
| `infra/service_linked_roles` | Enables EC2 Spot functionality        |

### Cost & Policy Management

| Module                  | Purpose                                      |
|-------------------------|----------------------------------------------|
| `infra/budget`          | Creates AWS budget alerts                    |
| `infra/billing`         | Adds CloudWatch billing alarms               |
| `infra/cloud_custodian` | Applies cleanup/governance rules             |

---

## Integrations

Optional modules for observability, access, and compliance.

| Module                  | Notes                                         |
|-------------------------|-----------------------------------------------|
| `integrations/splunk_*` | Set of modules for Splunk Cloud, secrets, dashboards |
| `integrations/teleport` | Enables audit/session capture via Teleport    |

---

## Secrets and Identity

| Item                     | Purpose                                       |
|--------------------------|-----------------------------------------------|
| `infra/secrets`          | Provisions secrets for GitHub Apps and Splunk |
| [Secrets Reference](./secrets.md) | Documents required keys, formats, scopes |
| [Dependency Guide](./dependency.md) | Shows setup order across modules     |

---

## Deployment Scenarios

Ready-made configuration examples:

- [First Tenant Deployment](./deployments/forge_tenant.md)
- [Splunk Integration](./deployments/splunk_deployment.md)

View all: [Deployment Index](./deployments/index.md)

---

## Recommended Setup Order

1. Deploy base `infra/` modules (VPCs, EKS, IAM, S3, etc.)
2. Deploy `platform/forge_runners`
3. Configure secrets and tenant GitHub Apps
4. Enable integrations (e.g., Splunk, Teleport)
