# Tenant Request Template

Use this as a Markdown issue body, ticket template, or pull request checklist.
Each company can adapt the approval fields to its internal process.

## Summary

- Tenant name:
- Request owner:
- Support owner:
- GitHub organization or GHES URL:
- Repositories or runner group:
- Environment:
- Requested start date:

## Runner Need

- Runner lane: EC2 / ARC / both
- Operating system: Linux / Windows / macOS
- Architecture: x64 / arm64
- Runner labels requested:
- Maximum parallel jobs:
- Expected weekly job volume:
- Does the tenant need Docker builds: yes / no
- Does the tenant need privileged Docker-in-Docker: yes / no

## AWS Access

- AWS account IDs used by jobs:
- IAM role ARNs runners should assume:
- ECR registries runners should access:
- S3 buckets runners should access:
- KMS keys runners should use:
- Network/VPC requirements:

## Images

- Base AMI name or owner:
- Custom AMI required: yes / no
- Required toolchains:
- Container runner image required for ARC: yes / no
- Image owner:

## GitHub App

- Repository selection: all / selected
- Selected repositories:
- GitHub App owner/admin:
- Installation ID:
- App ID:
- Client ID:
- App name:

Do not paste the private key into this request. Store it through the documented
SSM Parameter Store flow.

## Integrations

- Splunk required: yes / no
- Teleport required: yes / no
- Webhook relay required: yes / no
- Other observability platform:

## Acceptance Criteria

- Tenant config has been added to the platform IaC repo.
- GitHub App is installed on the selected repositories or organization.
- GitHub App key SSM parameter contains the real base64 PEM.
- `terragrunt plan` is clean.
- `terragrunt apply` completed.
- EC2 smoke workflow passes, if EC2 is enabled.
- ARC smoke workflow passes, if ARC is enabled.
- Tenant AWS role assumption works without static AWS keys.
- Tenant support owner knows the runner labels and escalation path.
