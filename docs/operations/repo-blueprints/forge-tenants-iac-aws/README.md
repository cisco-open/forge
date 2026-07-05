# Repo: forge-tenants-iac-aws

Purpose: manage tenant-facing Forge runtime configuration. This repo owns
tenant folders, runner labels/specs, GitHub org mapping, webhook relay settings,
and platform module release references.

```text
forge-tenants-iac-aws/
├── .github/workflows/
│   ├── promotion.yml
│   ├── regression-tests.yml
│   └── rw-terragrunt.yml
├── release_versions.yml
└── terraform/
    ├── _global_settings/tenant.hcl
    └── environments/prod/regions/eu-west-1/vpcs/main/tenants/acme/
        ├── config.yml
        ├── runner_settings.hcl
        └── terragrunt.hcl
```

Keep this repo focused on platform runtime and tenants. EKS, ECR, AMI sharing,
and ops buckets belong in `forge-infra-iac-aws`.
