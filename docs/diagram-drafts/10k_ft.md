# 10k Foot Forge Overview

Source image: `../img/10k_ft.jpg`

## Textual Description

This diagram shows a single Forge tenant deployment. The AWS Cloud board
contains a Forge account and a tenant AWS account. Inside the Forge account, a
region contains one Forge instance for the tenant. That instance has a Forge
control plane that creates or coordinates ephemeral VM runners and ephemeral pod
runners.

The tenant AWS account contains the IAM role, ECR, tenant GitHub runner AMI,
and tenant action runner artifacts used by that tenant. The GitHub board shows
a tenant-managed repository, the Forge GitHub App, and a Forge GitHub runner
group. A user pushes code to the repository, the app is installed in the
repository, and workflows route jobs to the runner group.

## Mermaid Draft

```mermaid
%%{init: {"theme": "base", "securityLevel": "loose", "themeVariables": {"fontFamily": "Inter, Arial, sans-serif", "fontSize": "13px", "darkMode": false, "background": "#ffffff", "lineColor": "#111827", "primaryTextColor": "#111827"}}}%%
block
  columns 1

  block:AWS
    columns 2

    block:FORGE
      columns 1
      block:REGION
        columns 1
        block:INSTANCE
          columns 3
          VM["<img src='http://127.0.0.1:8123/assets/ec2-instances.svg' width='58'/><br/><b>Ephemeral<br/>VM Runners</b>"]
          CONTROL["<img src='http://127.0.0.1:8123/assets/control-plane.svg' width='76'/><br/><b>Forge Control<br/>Plane</b>"]
          POD["<img src='http://127.0.0.1:8123/assets/pod.svg' width='58'/><br/><b>Ephemeral<br/>Pod Runner</b>"]
        end
      end
    end

    block:TENANT
      columns 2
      TENANT_IAM["<img src='http://127.0.0.1:8123/assets/iam-role.svg' width='58'/><br/><b>Tenant IAM<br/>Role</b>"]
      TENANT_ECR["<img src='http://127.0.0.1:8123/assets/ecr.svg' width='58'/><br/><b>Tenant ECR</b>"]
      TENANT_AMI["<img src='http://127.0.0.1:8123/assets/ami.svg' width='58'/><br/><b>Tenant GH<br/>Runner AMI</b>"]
      TENANT_ACTION["<img src='http://127.0.0.1:8123/assets/ecr.svg' width='58'/><br/><b>Tenant Action<br/>Runner</b>"]
    end
  end

  block:GITHUB
    columns 2
    block:TENANT_MANAGED
      columns 3
      USER["<img src='http://127.0.0.1:8123/assets/user-line.svg' width='58'/><br/><b>User</b>"]
      APP["<img src='http://127.0.0.1:8123/assets/github-app.svg' width='64'/><br/><b>Forge Github App</b>"]
      REPO["<img src='http://127.0.0.1:8123/assets/git-repository-line.svg' width='64'/><br/><b>Git Repository</b>"]
    end
    block:RUNNER_GROUP
      columns 3
      RUNNER_ABC["<img src='http://127.0.0.1:8123/assets/github-runner.svg' width='48'/><br/>Runner abc"]
      RUNNER_BCD["<img src='http://127.0.0.1:8123/assets/github-runner.svg' width='48'/><br/>Runner bcd"]
      RUNNER_CDE["<img src='http://127.0.0.1:8123/assets/github-runner.svg' width='48'/><br/>Runner cde"]
      RUNNER_DEF["<img src='http://127.0.0.1:8123/assets/github-runner.svg' width='48'/><br/>Runner def"]
      RUNNER_EFG["<img src='http://127.0.0.1:8123/assets/github-runner.svg' width='48'/><br/>Runner efg"]
      RUNNER_FGH["<img src='http://127.0.0.1:8123/assets/github-runner.svg' width='48'/><br/>Runner fgh"]
    end
  end

  CONTROL --> VM
  CONTROL --> POD
  CONTROL --> TENANT_IAM
  CONTROL --> RUNNER_ABC
  APP --> CONTROL
  USER --> REPO
  APP --> REPO
  REPO --> RUNNER_ABC

  style AWS fill:#ffffff,stroke:#334155,stroke-width:2px,stroke-dasharray:6 6
  style FORGE fill:#fff7fb,stroke:#db2777,stroke-width:2px
  style REGION fill:#f0fdf4,stroke:#059669,stroke-width:2px
  style INSTANCE fill:#f0f7ff,stroke:#0284c7,stroke-width:2px,stroke-dasharray:6 6
  style TENANT fill:#fff7fb,stroke:#e11d48,stroke-width:2px
  style GITHUB fill:#faf5ff,stroke:#7e22ce,stroke-width:2px,stroke-dasharray:6 6
  style TENANT_MANAGED fill:#fee2e2,stroke:#dc2626,stroke-width:2px,stroke-dasharray:6 6
  style RUNNER_GROUP fill:#fce7f3,stroke:#be185d,stroke-width:2px,stroke-dasharray:6 6
```

## Evidence Used

- `README.md`: ForgeMT is an AWS GitHub Actions runner platform with secure
  multi-tenancy, ephemeral EC2 and Kubernetes runners, GitHub App management,
  and optional observability.
- `modules/platform/forge_runners/README.md`: The tenant stack composes EC2
  runners, ARC runners, GitHub App settings, runner group reconciliation,
  trust validation, log archival, and webhook relay.
- `modules/platform/forge_runners/roles.tf`: Forge runner policies include
  `sts:AssumeRole`, `sts:TagSession`, and ECR pull permissions.

## Review Notes

- The source image shows the Forge GitHub App connected into the repository and
  Forge control plane, but does not label the exact event type. The draft uses
  `Webhook app events`; review before publishing.
- Exact AWS/Miro-style icons are available in the rendered PNG through the
  local `aws-forge` icon pack. Raw GitHub Mermaid may need an icon fallback if
  the diagram is embedded directly instead of using the exported PNG.
- This draft uses Mermaid `block` layout so the AWS and GitHub boards stay in
  the same organization as the source image. Block links do not support normal
  edge labels, so relationship details are kept in the description.
