# Pipeline Pattern Catalog

These patterns describe the pipeline logic observed across the operations
repositories in a platform-neutral form.

## Three-Layer Workflow Model

| Layer              | Responsibility                                                       | Review Questions                                               |
| ------------------ | -------------------------------------------------------------------- | -------------------------------------------------------------- |
| Entry workflow     | Defines triggers, permissions, concurrency, and high-level inputs.   | Does this run only when intended? Are permissions minimal?     |
| Reusable workflow  | Defines the reusable execution contract and orchestration order.     | Are inputs explicit? Are dry-run and apply modes separated?    |
| Local task adapter | Performs one local task such as build, validate, publish, or deploy. | Can it be tested locally? Does it hide private wiring cleanly? |

## Quality Gate

Use for every repository.

- Trigger on pull requests and pushes to protected branches.
- Run repo-local formatting, linting, policy, and secret-scan hooks.
- Keep permissions read-only unless the check must comment on the PR.
- Require maintainers to include validation evidence in the PR.

Anti-pattern: adding a second untracked quality path that bypasses the local
hooks.

## Workflow Change Safety

Use when editing automation files.

- Keep trigger changes isolated and easy to review.
- Review `permissions`, `concurrency`, `paths`, and manual inputs together.
- Pin third-party actions or document the version policy.
- Validate workflow syntax and the repo-local hooks before pushing.

Anti-pattern: changing workflow behavior while also refactoring unrelated
repository code.

## Discovery To Matrix

Use when the repository structure determines what must run.

- Discover target paths from the checked-out tree.
- Convert discovered paths into a structured matrix.
- Include useful metadata in each matrix entry, such as environment, region,
  tenant, component, or path.
- Use `fail-fast: false` for independent matrix entries so one failure does not
  hide the rest of the impact.

Anti-pattern: hardcoding all targets in workflow YAML when the repo already
contains the source of truth.

## Dry-Run And Apply Split

Use for infrastructure, migrations, and any operation that changes remote
state.

- Pull requests run dry-run validation only.
- Protected branches can run apply after review.
- Manual dispatch can force a scoped operation with explicit inputs.
- Apply jobs require a protected environment or equivalent approval gate.

Anti-pattern: allowing pull request workflows to modify persistent state.

## Migration Orchestration

Use when a change must move tenants, workloads, or environments between states.

- Disable competing scheduled workflows before migration.
- Discover current active and inactive targets.
- Execute destroy, recreate, migrate, and scale phases as separate jobs.
- Re-enable normal workflows after successful completion.
- Keep the migration state visible through summaries.

Anti-pattern: a single opaque job that performs every phase without resumable
boundaries.

## Scheduled Maintenance

Use for dependency updates, drift scans, stale PR hygiene, docs publication, and
periodic smoke tests.

- Pair `schedule` with `workflow_dispatch`.
- Add concurrency so overlapping runs cannot race.
- Emit a summary artifact or page when the result is useful to humans.
- Keep write permissions limited to the target artifact.

Anti-pattern: scheduled jobs that mutate repositories without clear ownership
or audit output.

## Release And Version Handling

Use when publishing shared actions, images, modules, or docs.

- Make the release trigger explicit.
- Derive version type from branch, label, input, or commit convention.
- Build first, publish second, validate third.
- Store release notes and generated metadata in predictable locations.

Anti-pattern: publishing a new artifact without a validation job that consumes
it.

## Image Factory

Use when baking runner images.

- Compute version before building.
- Support a build matrix by image family, operating system, version, and
  architecture.
- Allow intentional skip flags for expensive matrix entries.
- Collect successfully built images into a smoke-test matrix.
- Test the candidate image before publishing or handing it to downstream
  consumers.

Anti-pattern: treating a successful bake as proof that the image can run jobs.

## Repository Factory

Use when repository settings should be governed as declared state.

- Store repository entries in a catalog.
- Derive repository creation, team access, metadata, webhooks, branch
  protection, and required checks from the catalog.
- Dry-run catalog changes before applying them.
- Keep manual follow-ups explicit in the PR.

Anti-pattern: creating a repository by hand and backfilling catalog state later.

## Dependency Automation

Use when a bot keeps versions, lockfiles, images, and generated docs current.

- Run on a schedule and support manual dispatch.
- Keep manager config in the repo.
- Use local adapters for private package access.
- Group updates so reviewers can keep up.
- Publish failed lookups and unsupported updates.

Anti-pattern: treating a dependency scan with lookup failures as a clean run.

## PR Validation Aggregator

Use when a workflow has many conditional jobs.

- Add a final job that depends on all relevant jobs.
- Run it with `always()`.
- Fail when any required dependency failed or was cancelled.
- Use it as the required status check instead of requiring every matrix job by
  name.

Anti-pattern: branch protection depending on dynamic matrix job names.

## Report Or Page Publishing

Use when operations output is useful beyond the raw workflow logs.

- Gather structured data from source repos or workflow artifacts.
- Generate one compact landing page plus separate detailed pages.
- Deploy from a dedicated job with only the permissions it needs.
- Keep the generated output reproducible from repository state.

Anti-pattern: hiding operational status in private workflow logs only.

## Portable Controls

- Minimal permissions by default.
- Explicit concurrency groups.
- Manual dispatch for dangerous operations.
- Protected environments for apply or publish.
- Local adapters for private integrations.
- Structured summaries for human review.
- No secrets in logs, docs, examples, or templates.
