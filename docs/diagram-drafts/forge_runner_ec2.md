# Forge EC2 Runner Detail

Source image: `../img/forge_runner_ec2.jpg`

## Textual Description

This diagram shows the EC2 runner lane inside one Forge tenant instance. The
Forge account contains a region with Forge GitHub runner AMIs, Forge Ops ECRs,
the Forge GitHub ephemeral VM runners, the API Gateway endpoint, webhook job,
warm pool job, and CloudWatch Logs.

The Forge Runner IAM roles attach to EC2 runners by instance profile. The AMI
defines the VM image used by Forge runners, and Forge Ops ECRs provide images
that can run on top of Forge runners. The API Gateway endpoint triggers the
webhook job, the webhook job and warm pool job can spin VM runners, and runner
plus Lambda execution logs flow into Amazon CloudWatch Logs.

## Mermaid Draft

```mermaid
%%{init: {"theme": "base", "securityLevel": "loose", "themeVariables": {"fontFamily": "Inter, Arial, sans-serif", "fontSize": "13px", "darkMode": false, "background": "#ffffff", "lineColor": "#111827", "primaryTextColor": "#111827"}}}%%
block
  columns 1

  block:AWS
    columns 1

    block:FORGE
      columns 1

      block:INSTANCE
        columns 1

        block:REGION
          columns 5
          space
          space
          FORGE_ROLES["<img src='http://127.0.0.1:8123/assets/iam-role.svg' width='62'/><br/><b>Forge Runner<br/>IAM Roles</b>"]
          space
          space
          AMI["<img src='http://127.0.0.1:8123/assets/ami.svg' width='58'/><br/><b>Forge GH<br/>Runner AMI</b>"]
          space
          VM["<img src='http://127.0.0.1:8123/assets/ec2-instances.svg' width='62'/><br/><b>Forge GH<br/>Ephemeral VM<br/>Runners</b>"]
          space
          WARM_POOL["<img src='http://127.0.0.1:8123/assets/lambda.svg' width='58'/><br/><b>Warm pool<br/>job</b>"]
          OPS_ECR["<img src='http://127.0.0.1:8123/assets/ecr.svg' width='58'/><br/><b>Forge Ops<br/>ECRs</b>"]
          space
          WEBHOOK["<img src='http://127.0.0.1:8123/assets/lambda.svg' width='58'/><br/><b>Webhook job</b>"]
          CLOUDWATCH["<img src='http://127.0.0.1:8123/assets/cloudwatch.svg' width='58'/><br/><b>Amazon<br/>CloudWatch<br/>Logs</b>"]
          space
          API_GATEWAY["<img src='http://127.0.0.1:8123/assets/api-gateway.svg' width='58'/><br/><b>Amazon API<br/>Gateway<br/>Endpoint</b>"]
          space
          space
          space
          space
        end
      end
    end
  end

  FORGE_ROLES --> VM
  AMI --> VM
  OPS_ECR --> VM
  API_GATEWAY --> WEBHOOK
  WEBHOOK --> VM
  WARM_POOL --> VM
  VM --> CLOUDWATCH
  WEBHOOK --> CLOUDWATCH
  WARM_POOL --> CLOUDWATCH

  style AWS fill:#ffffff,stroke:#334155,stroke-width:2px,stroke-dasharray:6 6
  style FORGE fill:#fff7fb,stroke:#db2777,stroke-width:2px
  style INSTANCE fill:#f0f7ff,stroke:#0284c7,stroke-width:2px,stroke-dasharray:6 6
  style REGION fill:#f0fdf4,stroke:#059669,stroke-width:2px

```

## Evidence Used

- `modules/platform/ec2_deployment/README.md`: The EC2 lane uses the upstream
  `terraform-aws-github-runner` multi-runner module, handles webhook,
  scale-up, scale-down, ephemeral registration, label matching, AMI selection,
  warm pools, capacity type, tags, and logging hooks.
- `modules/platform/ec2_deployment/main.tf`: The module configures the
  upstream multi-runner module with GitHub App auth, EventBridge, logging,
  subnet IDs, KMS, and runner configuration.
- `modules/platform/forge_runners/ec2_runners.tf`: The umbrella tenant module
  passes tenant ECR registries, runner IAM policy ARNs, GitHub App values, and
  runner group name into `ec2_deployment`.

## Review Notes

- The source diagram uses generic labels `Webhook job` and `Warm pool job`
  rather than exact Lambda names. This draft keeps those labels.
- The source image shows both Lambda jobs sending execution logs to
  CloudWatch. It does not show EventBridge explicitly, even though the EC2
  module configures EventBridge, so EventBridge is intentionally omitted here.
- This draft uses Mermaid `block` layout so the EC2 runner board stays compact
  like the source image. Block links do not support normal edge labels, so
  relationship details are kept in the description.
