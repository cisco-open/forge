# Deployment Order

The first goal is one working Forge tenant. Do not block that on optional
integrations.

## Recommended Order

| Order | Deploy                                        | Example root                                             | Required?    |
| ----- | --------------------------------------------- | -------------------------------------------------------- | ------------ |
| 1     | State backend, deployment roles, shared tags  | Your bootstrap process                                   | Yes          |
| 2     | Account helpers needed before resources exist | `examples/deployments/helpers`                           | Sometimes    |
| 3     | EKS foundation                                | `examples/deployments/infra`                             | Only for ARC |
| 4     | One Forge tenant                              | `examples/deployments/platform`                          | Yes          |
| 5     | Remaining helpers                             | `examples/deployments/helpers`                           | Optional     |
| 6     | Integrations                                  | `examples/deployments/integrations`                      | Optional     |
| 7     | Weekly example validation                     | `docs/operations/repo-blueprints/forge-examples-iac-aws` | Recommended  |

## Minimal First Tenant Start

```bash
cd examples/deployments/platform/terragrunt
terragrunt run-all init
terragrunt run-all plan
```

Use this when you already have the foundations for the runner lane you selected.
For EC2, that means:

- enabled AWS region
- service-linked roles
- runner AMI
- VPC and subnets
- GitHub App secrets

For ARC, deploy the EKS foundation first, then apply the platform tenant with
`arc_runner_specs`.

## ARC Start

If tenant configs include `arc_runner_specs`, deploy EKS before the platform
tenant:

```bash
cd examples/deployments/infra/terragrunt
terragrunt run-all init
terragrunt run-all plan
```

Then deploy the platform tenant.

## Optional Integrations

Deploy integrations after the platform runner path works. If Splunk, Teleport,
or webhook relay destination modules are not part of your company design, leave
them out of `examples/deployments/integrations`.
