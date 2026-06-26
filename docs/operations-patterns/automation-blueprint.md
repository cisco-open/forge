# Forge Automation Blueprint

This page turns the observed operations repositories into a portable automation
map. It describes the shape of each automation family without copying private
actions, credentials, registry paths, or organization names.

## Automation Map

| Family                | Purpose                                                                            | Typical Triggers                       | Core Contract                                                                                     | Evidence                                                                |
| --------------------- | ---------------------------------------------------------------------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Image factory         | Bake runner images, test them, and publish only verified candidates.               | Pull request, push, manual dispatch.   | Compute version, decide matrix, bake image, collect test matrix, smoke test, aggregate PR status. | Image identifiers, build logs, smoke test result, final validation job. |
| Container factory     | Build support containers and verify the produced image can start.                  | Pull request, push, manual dispatch.   | Build image, tag/version, scan or lint, smoke-check with expected command.                        | Image tag, digest, check output.                                        |
| IaC operations        | Dry-run on PRs and apply from protected paths.                                     | Pull request, protected push, dispatch | Discover units, group by dependency layer, dry-run or apply per unit, aggregate status.           | Changed paths, dry-run summary, apply summary, final validation job.    |
| Repository factory    | Create repositories and apply branch protections, teams, metadata, and webhooks.   | Catalog change, manual dispatch.       | Validate catalog, dry-run changes, apply approved state, verify resulting settings.               | Catalog diff, dry-run summary, applied repository list, drift check.    |
| Scheduled jobs        | Run recurring hygiene without a human starting each job.                           | Schedule plus manual dispatch.         | Acquire lock, run scoped task, emit summary, fail loudly on partial state.                        | Summary artifact, changed resources, skipped resources.                 |
| Policy hygiene        | Enforce platform policy and report drift.                                          | Schedule plus manual dispatch.         | Load policy set, run read-only scan or approved remediation, publish findings.                    | Findings summary, exemptions, remediation result.                       |
| Dependency automation | Keep dependencies current with controlled PRs and post-update validation.          | Schedule plus manual dispatch.         | Load dependency config, authenticate through an adapter, open PRs, run validation.                | Dependency PRs, update log, failed lookup list.                         |
| Migration flow        | Move tenants or workloads between active and inactive states without hand driving. | Manual dispatch.                       | Discover active state, disable competing jobs, execute phased migration, re-enable normal jobs.   | Phase summary, tenant matrix, rollback checkpoint.                      |

## Common Contract

Every automation family should answer the same questions:

- What is the source of truth?
- What is discovered at runtime?
- Which step is read-only validation?
- Which step can mutate state?
- What approval gate protects mutation?
- What final status check should branch protection depend on?
- What evidence is left for the next maintainer?

## Adapter Boundary

Keep private implementation behind local adapters:

- Authentication.
- Registry login.
- Environment selection.
- Deployment engine setup.
- Notification or request-system updates.
- Secret retrieval.

The portable skeleton should name the adapter purpose, not the private command.

## PR Status Pattern

For large automations, require one stable final status:

1. Discover work.
1. Run conditional or matrix jobs.
1. Run a final `validate` job with `always()`.
1. Fail `validate` when any required job failed or was cancelled.
1. Make branch protection depend on `validate`, not dynamic matrix job names.

## Summary Pattern

Every scheduled, migration, image, and repository automation should publish a
human-readable summary:

- Inputs used.
- Targets discovered.
- Targets changed.
- Targets skipped.
- Failures and retry guidance.
- Rollback or resume point.

## Example Templates

Concrete snippets live under `examples/`:

- `examples/image-factory-workflow.md`
- `examples/container-factory-workflow.md`
- `examples/iac-operations-workflow.md`
- `examples/repository-factory-catalog.md`
- `examples/scheduled-job-workflow.md`
- `examples/policy-hygiene-job.md`
- `examples/dependency-automation-config.md`
- `examples/migration-orchestration-workflow.md`
