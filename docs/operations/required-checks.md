# Required Checks

Use these checks before merging Forge operating repo changes.

## Terraform And Terragrunt

```bash
tofu fmt -check -recursive .
terragrunt hcl format --check --diff --working-dir terraform
```

Run targeted plans from the changed environment folders.

## Workflows

- Validate YAML.
- Keep actions pinned to a tag or SHA according to your policy.
- Use protected environments for applies.
- Use concurrency for shared state.
- Keep `workflow_dispatch` on scheduled maintenance jobs.

## Docs And Examples

For the Forge source repo:

```bash
mkdocs build --strict
```

For examples repos, run weekly apply/destroy in this order:

```text
helpers -> infra -> platform -> integrations
integrations -> platform -> infra -> helpers
```
