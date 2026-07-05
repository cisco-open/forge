# Release Versions

Each example category has its own release file:

```text
examples/deployments/helpers/release_versions.yml
examples/deployments/infra/release_versions.yml
examples/deployments/platform/release_versions.yml
examples/deployments/integrations/release_versions.yml
```

Consumers should read module paths from these files instead of hardcoding source
paths in every Terragrunt stack.

## Why

Release files keep module source changes reviewable in one place. Tenant and
environment stacks should consume these values instead of hardcoding module
source addresses repeatedly.

```yaml
storage:
  module_path: modules/helpers/storage
  ref: <forge-release-tag-or-commit>
```

## Local Development

For local validation, point the release file or Terragrunt locals at the local
Forge checkout. For release validation, use a tag or commit SHA.

Keep module paths aligned with the current categories:

- `modules/platform`
- `modules/infra`
- `modules/helpers`
- `modules/integrations`
