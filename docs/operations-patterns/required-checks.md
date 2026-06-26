# Required Check Naming

Branch protection should depend on stable final checks, not dynamic matrix job
names. This keeps required checks predictable even when matrix entries change.

## Recommended Checks

| Automation            | Required Check                  | Why                                                             |
| --------------------- | ------------------------------- | --------------------------------------------------------------- |
| Quality gate          | `run-pre-commit`                | Stable baseline quality check.                                  |
| Image factory         | `validate`                      | Aggregates build, test, downstream, and skipped matrix entries. |
| Container factory     | `validate`                      | Confirms build and check-image completed.                       |
| IaC operations        | `validate`                      | Confirms discovery and dry-run jobs completed.                  |
| Repository factory    | `validate`                      | Confirms catalog validation and dry-run completed.              |
| Dependency automation | `validate` or repo quality gate | Confirms generated changes pass validation.                     |
| Migration             | no PR required check by default | Usually manual dispatch, summarized separately.                 |

## Rules

- Use one final `validate` job per complex workflow.
- Run `validate` with `if: always()`.
- Make `validate` inspect all required dependencies.
- Do not require matrix job names in branch protection.
- Do not require jobs that only run on protected branch apply.
- Keep the quality gate required for every repository.

## Example Validate Job

```yaml
validate:
  needs: [discover, dry-run]
  if: always()
  runs-on: <runner-label>
  steps:
    - shell: bash
      run: |
        test "${{ needs.discover.result }}" = "success"
        test "${{ needs.dry-run.result }}" = "success"
```

## Status Check Inventory

Track required checks in the repository catalog:

```yaml
required_checks:
  - "run-pre-commit"
  - "validate"
```
