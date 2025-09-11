# Forge Tenant Usage Guide

<!-- toc -->

- [Forge Tenant Usage Guide](#forge-tenant-usage-guide)
  - [Forge Tenant Quick Start Guide](#forge-tenant-quick-start-guide)
    - [What is Forge?](#what-is-forge)
    - [How to use Forge runners](#how-to-use-forge-runners)
    - [Adding your repository to Forge](#adding-your-repository-to-forge)
  - [Forge Multi-Tenant Overview](#forge-multi-tenant-overview)
    - [🔄 Dependency Management](#-dependency-management)
  - [⚙️ Advanced Configuration (Optional)](#%EF%B8%8F-advanced-configuration-optional)
    - [🔐 Optional AWS Access for Runners](#-optional-aws-access-for-runners)
      - [⚙️ Configuring AWS Access (Optional)](#%EF%B8%8F-configuring-aws-access-optional)
      - [🔄 Example: Assume Role in External AWS Account (Optional)](#-example-assume-role-in-external-aws-account-optional)
      - [🐳 Running Jobs in Containers](#-running-jobs-in-containers)
        - [1. **Create an ECR Policy for the Forge Runner**](#1-create-an-ecr-policy-for-the-forge-runner)
        - [2. **Attach the Policy to the Forge Runner IAM Role**](#2-attach-the-policy-to-the-forge-runner-iam-role)
        - [3. **Configure the Runner to Access the ECR Repository**](#3-configure-the-runner-to-access-the-ecr-repository)
    - [🔍 Observation](#-observation)
    - [🔧 How to Configure a Repository for Runners](#-how-to-configure-a-repository-for-runners)
      - [1. Navigate to the Repository](#1-navigate-to-the-repository)
      - [2. Access Configuration Options](#2-access-configuration-options)
      - [3. Select Repositories](#3-select-repositories)
      - [5. Ready for Runners](#5-ready-for-runners)

<!-- tocstop -->

## Forge Tenant Quick Start Guide

### What is Forge?

Forge runs your GitHub Actions workflows on managed runners in Forge team AWS accounts — no infra management needed. You just write your workflow and pick the runner type.

### How to use Forge runners

1. **Pick a runner type for your job:**

| Runner Type  | Description                                                               |
| ------------ | ------------------------------------------------------------------------- |
| `small`      | Lightweight, cost-effective runner                                        |
| `standard`   | Balanced performance for general workloads                                |
| `large`      | High-performance runner for demanding jobs                                |
| `metal`      | Bare-metal runner for heavy workloads                                     |
| `dependabot` | Dedicated runner for Dependabot automation jobs                           |
| `k8s`        | Kubernetes pod runner for lightweight jobs excluding Docker-based actions |
| `dind`       | Kubernetes pod runner supporting Docker-in-Docker (DinD) in rootless mode |

2. **Update your workflow:**

Add this snippet to `.github/workflows/your-workflow.yml`:

```yaml
jobs:
  build:
    runs-on:
      - self-hosted
      - x64
      - type: standard
```

For Kubernetes pods, use:

```yaml
jobs:
  build:
    runs-on:
      - k8s
```

3. **Request a new runner type**

If you need a runner type not listed here, contact the Forge team.

4. **(Optional) AWS resource access**

If your workflow needs to access external AWS resources (S3, EC2, etc.), check [advanced doc](#%EF%B8%8F-advanced-configuration-optional).

______________________________________________________________________

### Adding your repository to Forge

- Make sure the Forge GitHub App is installed on your repo.
- Go to your repo Settings → Installed GitHub Apps → Configure Forge app.
- Select the repos you want Forge runners enabled for.
- Once configured, push workflows using `runs-on: self-hosted` and Forge runners will pick them up.

______________________________________________________________________

## Forge Multi-Tenant Overview

Forge is designed for flexible, secure, and scalable CI/CD operations, integrating seamlessly with GitHub Actions. Key features include:

- ⚡ **Flexible Scaling**: Choose from predefined runner types (`dependabot`, `small`, `standard`, `large`, `metal`) to match workload needs.
- 🐳 **Container Support**: Run jobs in Docker containers for isolated execution.
- 🔐 **IAM Role-Based Access**: Securely access external AWS accounts with per-tenant IAM roles, ensuring strict permission control.
- 🖥️ **Secure Remote Access**: Enable SSH access via Teleport for debugging and troubleshooting.
- 📊 **Centralized Logging & Monitoring**: Automatically send logs to Splunk and integrate with CloudWatch for monitoring.
- 🔄 **Seamless GitHub Actions Integration**: Optimize CI/CD workflows effortlessly.
- 📦 **Automated Dependency Management**: Utilize **Dependabot** and **Renovate Bot** for automated updates.

______________________________________________________________________

### 🔄 Dependency Management

Forge supports automated dependency updates using **Dependabot** and **Renovate Bot**:

- 🤖 **Dependabot**: A GitHub-native tool that creates PRs to update dependencies automatically.
- 🔧 **Renovate Bot**: Offers advanced versioning strategies, scheduling, and fine-grained configuration.

[See the detailed comparison guide](./dependency-management.md).

______________________________________________________________________

## ⚙️ Advanced Configuration (Optional)

### 🔐 Optional AWS Access for Runners

By default, Forge Runners do not require access to external AWS resources. However, if a team needs the runner to interact with resources (e.g., launch EC2 instances, access DynamoDB, S3, or Secrets Manager), **IAM role-based access** can be configured.

#### ⚙️ Configuring AWS Access (Optional)

To allow the runner to access external AWS resources:

- 1. **External AWS IAM Role (Optional)**: The external AWS account must have IAM roles configured with the necessary permissions (e.g., EC2, DynamoDB, S3).
- 2. **Trust Relationship**: The external AWS role must trust the IAM role from the Forge account to allow the Forge runner to assume it.

#### 🔄 Example: Assume Role in External AWS Account (Optional)

To configure role assumption, the external AWS account must allow the Forge runner's role to assume its IAM role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::EXTERNAL_AWS_ACCOUNT_ID:role/ForgeRunnerRole"
    }
  ]
}
```

Once the Forge runner assumes this role, it will have the permissions defined in the external AWS account’s IAM role (e.g., to launch EC2 instances, access S3, pull ECR, etc.).

______________________________________________________________________

#### 🐳 Running Jobs in Containers

If your runner's AMI does not contain the necessary tools, you can run your job inside a Docker container.

To allow the Forge runner to pull a Docker image from Amazon ECR, you’ll need to create an ECR policy in the AWS account hosting the ECR repository. This policy should grant permissions to the Forge runner (or the IAM role it assumes) to pull images from ECR.

##### 1. **Create an ECR Policy for the Forge Runner**

Example ECR policy (JSON):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage"
      ],
      "Resource": "arn:aws:ecr:<aws-region>:<aws-account-id>:repository/<container-name>"
    }
  ]
}
```

Replace:

- `<aws-region>` with your ECR region
- `<aws-account-id>` with your AWS account ID hosting the ECR
- `<container-name>` with your ECR repo name

##### 2. **Attach the Policy to the Forge Runner IAM Role**

Attach this policy to the IAM role that the Forge runner uses.

##### 3. **Configure the Runner to Access the ECR Repository**

Ensure runner is set up to authenticate against the ECR repo. Usually this means your runner's IAM role can assume the role with this policy.

Example job YAML:

```yaml
jobs:
  my-job:
    runs-on:
      - self-hosted
      - x64
      - type:small
      - env:ops-prod
    timeout-minutes: 60

    container:
      image: <aws-account-id>.dkr.ecr.<aws-region>.amazonaws.com/<container-name>
```

______________________________________________________________________

### 🔍 Observation

- **Instance Selection**: Forge provisions the smallest available instance in the requested runner type within your AWS region.
- **Network Latency**: Pulling container images from ECR in a different region may introduce latency.

______________________________________________________________________

### 🔧 How to Configure a Repository for Runners

#### 1. Navigate to the Repository

Go to a repository where the **GitHub App for the tenant** is installed.

#### 2. Access Configuration Options

- Click **Configure** in repository settings.
- You'll be redirected to the page where you select repos for the Forge GitHub App.

#### 3. Select Repositories

- Select repos you want to enable Forge runners on.
- For multiple repos, select them all.

#### 5. Ready for Runners

Once approved, your repository is ready to use Forge runners.
