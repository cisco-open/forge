# Teleport

Teleport integration is optional. Use it only when your operators need Teleport
access or audit for Kubernetes runner infrastructure.

## Deploy When

- Forge owns EKS for ARC runners.
- Your access model requires Teleport agents.
- You have the Teleport endpoint, CA pin, join token, and labels from your
  access platform.

## Skip When

- You run EC2-only Forge runners.
- Kubernetes access is managed by another platform.
- You do not need remote access to runner infrastructure.

## Files

```text
modules/integrations/teleport
examples/deployments/integrations/terragrunt/_global_settings/teleport.hcl
examples/deployments/integrations/terragrunt/environments/prod/regions/eu-west-1/teleport/config.yml
```

Keep company-specific Teleport endpoints and CA values out of public examples.
