# Prerequisites

Make these decisions before changing Terraform or Terragrunt files.

## Accounts And Access

| Item                             | Required for         | Notes                                                                        |
| -------------------------------- | -------------------- | ---------------------------------------------------------------------------- |
| AWS account for Forge platform   | All deployments      | Owns runner infrastructure, state access, and platform-managed resources.    |
| AWS account for tenant workloads | When jobs access AWS | Target roles must trust the Forge runner role or your GitHub OIDC provider.  |
| Deployment role                  | All deployments      | Used by CI and local operators to run plan/apply.                            |
| State backend                    | All deployments      | S3 bucket and DynamoDB lock table, or your equivalent backend.               |
| Default region                   | All deployments      | Match examples first, then add more regions deliberately.                    |
| Tags                             | All deployments      | Include owner, environment, service, cost center, and security contact tags. |

## GitHub

You need:

- A GitHub organization or GHES instance.
- A Forge GitHub App per tenant or per operating boundary.
- Runner group names and repository access decisions.
- A secret backend for GitHub App ID, installation ID, private key, and webhook
  secret values.

## Tools

Local operators and CI runners should have:

```bash
aws --version
tofu version
terragrunt --version
git --version
```

Add these only when needed:

- `kubectl` and `helm` for EKS/ARC.
- `packer` and `ansible` for runner image repositories.
- `docker` or BuildKit for container repositories.
- `custodian` for Cloud Custodian policy repositories.

## Runner Images

For EC2 runners, decide how AMIs are built and shared before tenant configs
reference them. For ARC runners, decide which runner, DinD, and helper
container images are allowed.

Start with a single Linux EC2 AMI. Add macOS, Windows, ARM64, custom tenant
images, and ARC containers after the first tenant is working.

Use [Bootstrap](bootstrap.md) to connect these decisions to the actual
Terragrunt files, AWS profile, remote state backend, GitHub App, SSM key
parameter, and runner image flow.
