# Deployment Details

This folder documents the four deployable example roots. Each page tells you
which files to edit, which module category it consumes, and what to skip when
your platform already provides that capability.

| Deployment root                   | Use it when                                                                                             | Copy from                           | Skip when                                     |
| --------------------------------- | ------------------------------------------------------------------------------------------------------- | ----------------------------------- | --------------------------------------------- |
| [Platform](./platform.md)         | You need the Forge runner runtime for tenants.                                                          | `examples/deployments/platform`     | Never, if you want Forge-managed runners.     |
| [Infra / EKS](./infra.md)         | You need ARC/Kubernetes runner scale sets and Forge owns EKS.                                           | `examples/deployments/infra`        | You run EC2-only runners or use existing EKS. |
| [Helpers](./helpers.md)           | Forge owns AMI sharing, ECR, buckets, region opt-in, service-linked roles, or cleanup jobs.             | `examples/deployments/helpers`      | Your platform already owns those resources.   |
| [Integrations](./integrations.md) | You need Splunk, Teleport, webhook relay destinations, OTel, OpenCost, or another external integration. | `examples/deployments/integrations` | You only need core runner capacity.           |

Recommended first path:

```bash
cd examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme
terragrunt plan
terragrunt apply
```

After that works, add the next smallest scenario: EKS for ARC, a helper module,
or one integration.

## Related Runbooks

| Task                              | Go to                                                      |
| --------------------------------- | ---------------------------------------------------------- |
| Add a tenant                      | [Tenant Onboarding](../../operations/tenant-onboarding.md) |
| Move ARC tenants between clusters | [Move ARC Tenants](../../operations/move-arc-tenants.md)   |
| Build or update runner images     | [Runner Images](../../operations/runner-images.md)         |
| Configure Splunk                  | [Splunk Integration](../../integrations/splunk.md)         |
