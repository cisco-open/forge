# Configure Platform

The platform deployment is the Forge runtime. Start here for the first working
runner tenant.

Copy from:

```text
examples/deployments/platform
examples/templates/platform
```

## Main Module

The normal entry point is:

```text
modules/platform/forge_runners
```

It wires EC2 runner specs, ARC runner specs, GitHub App settings, tenant
metadata, webhook handling, job logs, and IAM boundaries.

## Files To Change First

```text
examples/deployments/platform/release_versions.yml
examples/deployments/platform/terragrunt/_global_settings/_global.yml
examples/deployments/platform/terragrunt/environments/prod/_environment_wide_settings/_environment.yml
examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/_region_wide_settings/_region.hcl
examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/_vpc_wide_settings/_vpc.yml
examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme/config.yml
examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme/runner_settings.hcl
```

## Minimum First Tenant

For the first tenant, pick one runner lane and keep the spec small.

EC2 first:

1. Keep one `ec2_runner_specs` entry.
1. Point it at a valid runner AMI.
1. Set tenant, region, VPC, subnet, and GitHub App values.
1. Remove or disable ARC runner specs until EKS is ready.
1. Run plan from the tenant folder.

ARC first:

1. Deploy or select the EKS foundation first.
1. Keep one `arc_runner_specs` entry.
1. Point it at a reachable runner container image.
1. Leave `ec2_runner_specs` empty until a runner AMI is ready.
1. Run plan from the tenant folder.

```bash
cd examples/deployments/platform/terragrunt/environments/prod/regions/eu-west-1/vpcs/main/tenants/acme
terragrunt plan
```

After apply, run a GitHub Actions workflow with the exact tenant labels from
the config.
