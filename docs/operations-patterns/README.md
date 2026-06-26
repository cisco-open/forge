# Forge Operations Patterns

This folder is a portable operations skeleton for maintaining Forge with the
same discipline used by the surrounding operations repositories, without
copying private company adapters, credential flows, or deployment-specific
implementation details.

It is intentionally Markdown-only. Treat it as a shareable playbook and
template kit, not as runnable automation.

## What This Captures

The source repositories share a few durable patterns:

- Every repository has a small quality gate that runs on pull requests and
  pushes.
- Operational work is split into entry workflows, reusable workflow contracts,
  and local task actions.
- Risky execution is separated from dry-run validation and guarded by protected
  environments.
- Dynamic infrastructure or tenant work is discovered from the repository
  structure before execution instead of being hardcoded in one static matrix.
- Scheduled maintenance jobs are treated as first-class workflows with
  concurrency controls and human-readable summaries.
- Review readiness is standardized with simple PR templates, validation
  evidence, and explicit risk notes.
- Agent or automation work is constrained by scope, local validation, and
  non-destructive defaults.

## Folder Map

| Path                      | Purpose                                                       |
| ------------------------- | ------------------------------------------------------------- |
| `automation-blueprint.md` | Map of the automation families that keep Forge low-touch.     |
| `repo-structure.md`       | Recommended repository layout and ownership boundaries.       |
| `pipeline-patterns.md`    | Reusable pipeline shapes extracted from the repos.            |
| `day-2-operations.md`     | Operating rhythm for day-to-day Forge maintenance.            |
| `adapter-contracts.md`    | Inputs, outputs, and behavior for local workflow adapters.    |
| `catalog-schemas.md`      | Example schemas for automation and repository catalogs.       |
| `script-interfaces.md`    | Stable local script arguments, outputs, and exit codes.       |
| `workflow-summaries.md`   | Example summaries for operators and reviewers.                |
| `rollback-examples.md`    | Rollback shapes for each automation family.                   |
| `required-checks.md`      | Stable final-check naming for branch protection.              |
| `ownership-matrix.md`     | Owner, backup, reviewer, and escalation template.             |
| `reference-skeleton/`     | Concrete repo folder tree for a Forge operations repo.        |
| `playbooks/`              | Focused runbooks for recurring maintainer workflows.          |
| `templates/`              | Fill-in documents for PRs, incidents, reviews, and repo maps. |
| `examples/`               | Copyable example snippets for each automation family.         |

## What Was Excluded

The scan found implementation details that should not be copied into this
portable skeleton:

- Company-owned GitHub actions and repository owners.
- Private registry images, numeric identifiers, and bot identities.
- Organization-specific login or credential bootstrap commands.
- Internal compliance, ticketing, chat, and observability system names.
- Deployment-tool installation flows and environment-specific adapters.

Those details can be reattached later behind local adapters, but the shared
pattern should stay platform-neutral.

## Adoption Checklist

1. Pick the Forge area: tenant lifecycle, runner images, integrations,
   examples, documentation, or release management.
1. Fill `templates/repo-map.md` for the area before changing files.
1. Fill `templates/automation-catalog.md` when the change touches image baking,
   repository management, scheduled jobs, or dependency automation.
1. Check `adapter-contracts.md` before adding or changing local adapters.
1. Check `script-interfaces.md` before adding scripts used by workflows.
1. Select the matching playbook from `playbooks/`.
1. Record the validation commands and outputs in `templates/change-record.md`.
1. Use `templates/pr-description.md` for reviewer-facing scope, risk, and
   rollback notes.

## Automation Families

Use these skeletons for the operational work that makes Forge maintainable:

| Automation                                           | Playbook                                 | Example                                        |
| ---------------------------------------------------- | ---------------------------------------- | ---------------------------------------------- |
| Bake and test runner images                          | `playbooks/image-bake-and-test.md`       | `examples/image-factory-workflow.md`           |
| Build and smoke-check containers                     | `playbooks/container-build-and-check.md` | `examples/container-factory-workflow.md`       |
| Manage IaC repositories                              | `playbooks/iac-repository-operations.md` | `examples/iac-operations-workflow.md`          |
| Create and govern repositories from a catalog        | `playbooks/repository-factory.md`        | `examples/repository-factory-catalog.md`       |
| Run cron-style scheduled maintenance jobs            | `playbooks/scheduled-jobs.md`            | `examples/scheduled-job-workflow.md`           |
| Run Custodian-style policy hygiene jobs              | `playbooks/policy-hygiene-jobs.md`       | `examples/policy-hygiene-job.md`               |
| Run Renovate-style dependency automation             | `playbooks/dependency-automation.md`     | `examples/dependency-automation-config.md`     |
| Orchestrate migrations and active/inactive rotations | `playbooks/migration-orchestration.md`   | `examples/migration-orchestration-workflow.md` |

## Design Rule

Keep the pattern generic and adapter-driven:

- The pattern describes what must happen.
- The local adapter decides how credentials, environments, runners, and
  deployment engines are wired.
- The PR explains which adapter was used and what validation proved.
