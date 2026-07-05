# Repo: forge-infra-iac-aws

Purpose: manage the infrastructure Forge needs before tenants can run: EKS,
ECR repositories, storage buckets, AMI sharing, service-linked roles, opt-in
regions, and other helper modules.

```text
forge-infra-iac-aws/
├── .github/workflows/promotion.yml
├── release_versions.yml
└── terraform/
    ├── _global_settings/
    └── environments/prod/
        ├── helpers/storage/
        └── regions/eu-west-1/
            ├── ecr/
            └── eks/
```

Keep this repo separate from tenants so cluster/helper changes can roll out
without editing tenant folders.
