# Forge EKS Runner Detail

Source image: `../img/forge_runner_eks.jpg`

## Textual Description

This diagram shows the Kubernetes/ARC runner lane inside one Forge tenant
instance. The Forge account contains a region with action runner images, Forge
Ops ECRs, the Forge EKS cluster, the runner pod, Forge EKS nodes, and the
tenant pods controller.

Forge Runner IAM roles attach to runner pods through Pod Identity. Action
runner ECR images are used to run the pod in Forge Kubernetes. Forge Ops ECRs
can run as container jobs in Kubernetes runners. The EKS cluster provides EKS
nodes, and the tenant pods controller schedules tenant pods onto nodes.

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
          ACTION_RUNNER["<img src='http://127.0.0.1:8123/assets/ecr.svg' width='58'/><br/><b>Action Runner</b>"]
          space
          POD["<img src='http://127.0.0.1:8123/assets/pod.svg' width='58'/><br/><b>Pod</b>"]
          space
          EKS_NODES["<img src='http://127.0.0.1:8123/assets/ec2-instances.svg' width='62'/><br/><b>Forge EKS<br/>Nodes</b>"]
          OPS_ECR["<img src='http://127.0.0.1:8123/assets/ecr.svg' width='58'/><br/><b>Forge Ops<br/>ECRs</b>"]
          space
          space
          space
          POD_CONTROLLER["<img src='http://127.0.0.1:8123/assets/pod.svg' width='58'/><br/><b>Tenant Pods<br/>Controller</b>"]
          EKS_CLUSTER["<img src='http://127.0.0.1:8123/assets/eks.svg' width='58'/><br/><b>Forge EKS<br/>Cluster</b>"]
          space
          space
          space
          space
        end
      end
    end
  end

  FORGE_ROLES --> POD
  ACTION_RUNNER --> POD
  POD --> EKS_NODES
  OPS_ECR --> EKS_NODES
  EKS_CLUSTER --> EKS_NODES
  POD_CONTROLLER --> EKS_NODES

  style AWS fill:#ffffff,stroke:#334155,stroke-width:2px,stroke-dasharray:6 6
  style FORGE fill:#fff7fb,stroke:#db2777,stroke-width:2px
  style INSTANCE fill:#f0f7ff,stroke:#0284c7,stroke-width:2px,stroke-dasharray:6 6
  style REGION fill:#f0fdf4,stroke:#059669,stroke-width:2px

```

## Evidence Used

- `modules/platform/arc/README.md`: The Kubernetes lane turns GitHub Actions
  jobs into ephemeral pods, installs ARC controller resources, creates scale
  sets, and applies Karpenter objects for tenant scheduling boundaries.
- `modules/platform/arc/scale_set/README.md`: A scale set creates one
  ephemeral runner pod per job and manages the runner IAM role, Kubernetes
  service account, EKS Pod Identity association, scale set labels, container
  images, resources, and volumes.
- `modules/infra/eks/README.md`: The EKS foundation provides the shared
  cluster for ARC runners, including Karpenter, Calico, EBS CSI, CoreDNS, and
  EKS Pod Identity add-ons.

## Review Notes

- The source image labels the central runtime simply as `Pod`. This draft does
  not expand it to `ARC runner pod` in the diagram label, but the description
  clarifies the documented ARC behavior.
- The image uses `K8S`; this draft keeps `K8S` only where it appears in edge
  labels and uses EKS/Kubernetes in descriptions.
- This draft uses Mermaid `block` layout so the EKS runner board stays compact
  like the source image. Block links do not support normal edge labels, so
  relationship details are kept in the description.
