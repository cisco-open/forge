# Repo: forge-examples-iac-aws

Purpose: prove the Forge examples still deploy. This repo should run weekly and
after large Forge module-layout or release-version changes.

```text
forge-examples-iac-aws/
├── .github/actions/terragrunt-deployment-action/action.yml
└── .github/workflows/
    ├── rw-example-category.yml
    └── test-examples.yml
```

The action checks out Forge, renders or updates example config, discovers
Terragrunt units, applies categories in dependency order, then destroys them in
reverse order.
