# 10k Foot Multi-Tenant Overview

Source image: `../img/10k_ft_multi_tenant.jpg`

## Textual Description

This diagram shows the same Forge account and AWS region hosting separate Forge
instances for Tenant A, Tenant B, and Tenant C. Each tenant instance has its own
Forge control plane, ephemeral VM runners, and ephemeral pod runner.

Each Forge instance connects to its matching tenant AWS account by assuming the
tenant IAM role. The diagram emphasizes that the Forge account can host multiple
tenant instances while tenant-side IAM roles remain separated by tenant account.

## Mermaid Draft

```mermaid
%%{init: {"theme": "base", "architecture": {"iconSize": 62, "fontSize": 14, "nodeSeparation": 105, "idealEdgeLengthMultiplier": 2.35, "edgeElasticity": 0.25, "numIter": 5000, "seed": 9}, "themeVariables": {"fontFamily": "Inter, Arial, sans-serif", "fontSize": "14px", "darkMode": false, "background": "#ffffff", "mainBkg": "#ffffff", "secondaryColor": "#ffffff", "tertiaryColor": "#ffffff", "clusterBkg": "#ffffff", "labelBackground": "#ffffff", "primaryTextColor": "#111827", "primaryColor": "#fff7fb", "primaryBorderColor": "#be185d", "lineColor": "#1f2937", "archEdgeColor": "#1f2937", "archEdgeArrowColor": "#1f2937", "archEdgeWidth": "2.8", "archGroupBorderColor": "#be185d", "archGroupBorderWidth": "2px"}}}%%
architecture-beta
  group aws(aws-forge:aws-cloud-logo)[AWS Cloud]
  group forge(aws-forge:aws-account)[Forge Account] in aws
  group region(aws-forge:region)[Region] in forge
  group tenant_accounts(aws-forge:aws-account)[Tenant AWS Accounts] in aws

  group inst_a[Forge Instance for Tenant A] in region
  group inst_b[Forge Instance for Tenant B] in region
  group inst_c[Forge Instance for Tenant C] in region

  service a_vm(aws-forge:ec2-instances)[Ephemeral VM Runners] in inst_a
  service a_control(aws-forge:control-plane)[Forge Control Plane] in inst_a
  service a_pod(aws-forge:pod)[Ephemeral Pod Runner] in inst_a

  service b_vm(aws-forge:ec2-instances)[Ephemeral VM Runners] in inst_b
  service b_control(aws-forge:control-plane)[Forge Control Plane] in inst_b
  service b_pod(aws-forge:pod)[Ephemeral Pod Runner] in inst_b

  service c_vm(aws-forge:ec2-instances)[Ephemeral VM Runners] in inst_c
  service c_control(aws-forge:control-plane)[Forge Control Plane] in inst_c
  service c_pod(aws-forge:pod)[Ephemeral Pod Runner] in inst_c

  group tenant_a(aws-forge:aws-account)[Tenant A AWS Account] in tenant_accounts
  group tenant_b(aws-forge:aws-account)[Tenant B AWS Account] in tenant_accounts
  group tenant_c(aws-forge:aws-account)[Tenant C AWS Account] in tenant_accounts

  service a_iam(aws-forge:iam-role)[Tenant IAM Role] in tenant_a
  service b_iam(aws-forge:iam-role)[Tenant IAM Role] in tenant_b
  service c_iam(aws-forge:iam-role)[Tenant IAM Role] in tenant_c

  a_control:L --> R:a_vm
  a_control:R --> L:a_pod
  a_control:T --> L:a_iam

  b_control:L --> R:b_vm
  b_control:R --> L:b_pod
  b_control:T --> L:b_iam

  c_control:L --> R:c_vm
  c_control:R --> L:c_pod
  c_control:T --> L:c_iam

  align row a_vm a_control a_pod a_iam
  align row b_vm b_control b_pod b_iam
  align row c_vm c_control c_pod c_iam
  align column a_vm b_vm c_vm
  align column a_control b_control c_control
  align column a_pod b_pod c_pod
  align column a_iam b_iam c_iam
```

## Evidence Used

- `README.md`: ForgeMT separates the control plane from the tenant plane and
  supports EC2 runners and EKS/ARC runners.
- `modules/platform/forge_runners/README.md`: The Forge runner stack is the
  normal tenant-facing module and wires EC2, ARC, GitHub App, runner group,
  trust validation, job logs, and relay behavior.

## Review Notes

- The source image is a high-level tenant repetition diagram. It only shows
  tenant IAM roles in the tenant AWS accounts, so ECR, AMIs, and action runner
  repositories are intentionally omitted here.
- This draft uses Mermaid `architecture-beta` so AWS Cloud, Forge Account,
  Region, Forge Instance, and Tenant AWS Account group labels are visible in
  the rendered diagram.
- `architecture-beta` does not support the same per-board fill and border
  styling as Mermaid `block` or flowchart diagrams. The layout preserves the
  source image's left-to-right Forge-to-tenant organization, but board colors
  are limited by the architecture renderer.
- The tenant-account arrows intentionally originate from the Forge control
  plane, matching the source image direction. The top port is used only to route
  those arrows above the pod runner lane.
