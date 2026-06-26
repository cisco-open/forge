# Repository Structure Pattern

Forge maintenance is smoother when each repository keeps a predictable boundary
between documentation, examples, modules, scripts, and automation contracts.

## Recommended Shape

```text
repo/
  .github/
    workflows/
    actions/
    PULL_REQUEST_TEMPLATE.md
  docs/
    operations-patterns/
    configurations/
    tenant-usage/
  examples/
  modules/
  scripts/
  CHANGELOG.md
  CONTRIBUTING.md
  README.md
```

## Ownership Boundaries

| Area                 | Owns                                                                | Should Not Own                                                       |
| -------------------- | ------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `.github/workflows/` | Trigger policy, permissions, reusable workflow calls, review gates. | Long shell scripts or environment-specific credential bootstrapping. |
| `.github/actions/`   | Local task adapters used by workflows.                              | Shared process documentation.                                        |
| `docs/`              | Operator and tenant-facing guidance.                                | Generated runtime state.                                             |
| `examples/`          | Minimal consumable deployments and tests.                           | Production-only configuration.                                       |
| `modules/`           | Reusable Forge building blocks.                                     | Tenant-specific secrets or local state.                              |
| `scripts/`           | Local maintenance helpers with clear inputs and outputs.            | Hidden CI-only business logic.                                       |
| `config/`            | Catalogs for repositories, schedules, policies, or dependency bots. | Secrets or generated runtime output.                                 |

## Maintenance Inventory

Create or update this table for every Forge maintenance area.

| Area                      | Source of Truth                  | Change Trigger                        | Validation                              | Rollback                           |
| ------------------------- | -------------------------------- | ------------------------------------- | --------------------------------------- | ---------------------------------- |
| Tenant configuration      | Repository config files          | Request, drift, or migration          | Parse config and dry-run impacted paths | Revert config change               |
| Runner image or container | Build recipe and version file    | Dependency, security, or feature need | Build and smoke test                    | Revert version and image reference |
| Integration               | Module config and alert contract | Alert gap or downstream field change  | Unit check, dry-run, sample payload     | Revert module/config change        |
| Documentation             | `docs/` and examples             | User confusion or release change      | Link check and reviewer read-through    | Revert doc patch                   |
| Release                   | Changelog and version metadata   | Approved merge or scheduled release   | Tags, generated notes, CI status        | Revert tag or release metadata     |

## Bootstrap Rules

1. Start from a clean branch unless intentionally carrying local work.
1. Confirm the repo-local quality gate before making broad edits.
1. Keep generated docs separate from human-written operator guidance.
1. Put environment-specific details in configuration, not in shared playbooks.
1. Keep private adapters behind local workflow actions or scripts.

## Repository Readiness Checklist

- `README.md` explains purpose, personas, and quick start.
- `CONTRIBUTING.md` explains local validation and PR expectations.
- `.github/PULL_REQUEST_TEMPLATE.md` asks for scope, type, testing, risk, and
  rollback.
- A quality workflow runs on pull requests and pushes.
- Expensive or destructive workflows can be manually dispatched and are guarded
  by environments.
- Repository, image, scheduled, and dependency automations have a documented
  source of truth.
- Generated outputs are documented as generated and not hand-edited.
- Secret handling is documented without exposing real secret names or values.
