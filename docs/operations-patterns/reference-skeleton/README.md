# Reference Operations Repo Skeleton

This is the concrete folder layout to copy when creating a Forge operations
repository. It shows where each automation family should live and what each
file is expected to own.

## Folder Tree

```text
forge-ops-example/
  .github/
    actions/
      auth-adapter/
        action.yml
      deployment-adapter/
        action.yml
      registry-adapter/
        action.yml
      notification-adapter/
        action.yml
      workflow-toggle-adapter/
        action.yml
    workflows/
      pre-commit.yml
      image-factory.yml
      container-factory.yml
      iac-operations.yml
      repository-factory.yml
      scheduled-maintenance.yml
      policy-hygiene.yml
      dependency-automation.yml
      runtime-migration.yml
    PULL_REQUEST_TEMPLATE.md
  config/
    automations.yaml
    repositories.yaml
    images.yaml
    containers.yaml
    schedules.yaml
    policies.yaml
    dependencies.json
    ownership.yaml
  docs/
    runbooks/
      image-factory.md
      repository-factory.md
      dependency-automation.md
      incident-response.md
    summaries/
      image-factory-summary.md
      policy-hygiene-summary.md
      migration-summary.md
  scripts/
    bake-image.sh
    test-runner-image.sh
    publish-image.sh
    build-container.sh
    check-container.sh
    discover-units.sh
    run-deployment.sh
    validate-repository-catalog.sh
    run-repository-factory.sh
    scheduled-maintenance.sh
    policy-hygiene.sh
    run-dependency-bot.sh
    discover-runtime-state.sh
    migrate-workload.sh
  schemas/
    automations.schema.json
    repositories.schema.json
    images.schema.json
    schedules.schema.json
    ownership.schema.json
  README.md
  CONTRIBUTING.md
```

## File Ownership

| File Or Folder               | Owns                                                                                      | Does Not Own                         |
| ---------------------------- | ----------------------------------------------------------------------------------------- | ------------------------------------ |
| `.github/workflows/`         | Triggers, permissions, concurrency, environments, final validation jobs.                  | Long operational logic.              |
| `.github/actions/*-adapter/` | Local access, registry, deployment, notification, and workflow toggle plumbing.           | Generic pattern documentation.       |
| `config/`                    | Declared source of truth for images, repos, schedules, policies, dependencies, ownership. | Secrets or generated runtime output. |
| `scripts/`                   | Local task implementation with stable arguments and exit codes.                           | Workflow trigger policy.             |
| `schemas/`                   | Validation contracts for config files.                                                    | Live environment state.              |
| `docs/runbooks/`             | Human operating guidance.                                                                 | Generated summaries.                 |
| `docs/summaries/`            | Example or generated summary shapes.                                                      | Source of truth configuration.       |

## Minimum Viable Repository

For a small Forge operations repo, start with:

- `.github/workflows/pre-commit.yml`
- `.github/workflows/scheduled-maintenance.yml`
- `.github/actions/auth-adapter/action.yml`
- `config/automations.yaml`
- `config/ownership.yaml`
- `scripts/scheduled-maintenance.sh`
- `schemas/automations.schema.json`
- `README.md`
- `CONTRIBUTING.md`

Add image, container, repository, dependency, and migration workflows only when
the repo owns those automation families.

## Golden Path

1. Add declared state under `config/`.
1. Validate declared state with a schema under `schemas/`.
1. Implement the smallest local task under `scripts/`.
1. Wrap local access or environment setup in `.github/actions/*-adapter/`.
1. Add a workflow that calls the adapter and script.
1. Add one stable final validation job.
1. Document owner, rollback, and summary output.

## Naming Conventions

| Item                 | Convention                                             |
| -------------------- | ------------------------------------------------------ |
| Final validation job | `validate`                                             |
| Read-only job        | `dry-run`, `scan`, or `check`                          |
| Mutating job         | `apply`, `publish`, `remediate`, or `migrate`          |
| Adapter action       | `<purpose>-adapter`                                    |
| Config file          | plural noun, for example `images.yaml`                 |
| Schema file          | matching config name, for example `images.schema.json` |
| Summary file         | `<automation>-summary.md`                              |
