# Module Contract Helper

## What This Is

This helper module lets native OpenTofu tests assert that specific Terraform
source literals remain present in a module under test.

## Why It Is Used

Some module contracts are structural: a module must continue to configure a
particular policy condition, environment variable, event source, or provider
shape. This helper gives module-local `.tftest.hcl` files a small offline way to
pin those contracts without initializing AWS providers.

## CI Execution

The helper is consumed by many `modules/**/tests/*.tftest.hcl` files during the
`IaC Policy` workflow. It is not run directly by CI.

## Local Execution

Run a consuming module's tests:

```bash
tofu -chdir=modules/<module-path> init -backend=false -input=false
tofu -chdir=modules/<module-path> test -no-color
```

Do not add provider-backed resources here. Helpers in this directory must remain
offline and safe to use without AWS credentials.
