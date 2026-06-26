# Operations Template Examples

These examples are copyable starting points. They show the structure of the
automation without private runner labels, registry hosts, credential commands,
organization names, or secret paths.

## Examples

| Example                               | Use For                                                               |
| ------------------------------------- | --------------------------------------------------------------------- |
| `image-factory-workflow.md`           | Baking runner images, testing them, and exposing one stable PR check. |
| `container-factory-workflow.md`       | Building and smoke-checking operational containers.                   |
| `iac-operations-workflow.md`          | Dry-running changes on PRs and applying from protected paths.         |
| `repository-factory-catalog.md`       | Creating repositories and applying governance from a catalog.         |
| `scheduled-job-workflow.md`           | Cron-style maintenance jobs with manual dispatch and summaries.       |
| `policy-hygiene-job.md`               | Custodian-style read-only scan and gated remediation jobs.            |
| `dependency-automation-config.md`     | Renovate-style dependency automation with validation.                 |
| `migration-orchestration-workflow.md` | Multi-phase active/inactive migration workflows.                      |

## Placeholder Convention

- Replace `<runner-label>` with the runner class used by the repo.
- Replace `<auth-adapter>` with the local authentication action or script.
- Replace `<registry-adapter>` with the local registry login action or script.
- Replace `<deployment-adapter>` with the local dry-run/apply action.
- Replace `<notification-adapter>` with the local summary, ticket, or chat
  adapter.
- Replace `<catalog-path>` with the repository catalog path.

Keep the private adapter implementation outside these examples.
