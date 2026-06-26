# Day-2 Operations Loop

This is the steady-state maintenance loop for Forge. It keeps urgent support,
planned changes, dependency updates, and platform hygiene in one operating
model.

## Daily

- Check failed CI or scheduled maintenance workflows.
- Triage tenant-facing incidents with the latest workflow logs and config diff.
- Review open pull requests for stuck checks, stale review comments, and missing
  validation evidence.
- Confirm no emergency change bypassed the documented rollback path.

## Weekly

- Review dependency update PRs and group them by risk.
- Check runner image, container, and example workflow drift.
- Review image bake and smoke-test results for recent tool or base updates.
- Confirm repository factory changes were applied through catalog review instead
  of manual settings drift.
- Verify dashboards, alerts, and runbooks still match current event fields.
- Review newly added tenants or workloads for config consistency.
- Close the loop on incident action items.

## Monthly

- Audit branch protection and required checks against current workflow names.
- Review scheduled jobs for stale credentials, disabled workflows, or silent
  failures.
- Review policy hygiene findings and expired exemptions.
- Refresh generated documentation and confirm human-written docs still explain
  the current behavior.
- Review cost, capacity, and queue-time signals for runner pools.
- Test at least one full tenant lifecycle in a non-production environment.

## Change Flow

1. Define the requested outcome and impacted area.
1. Fill `templates/repo-map.md` if the area is unfamiliar.
1. Choose the matching playbook.
1. Make the smallest scoped change.
1. Run the repo-local quality gate.
1. Run a dry-run or smoke test for the impacted area.
1. Fill `templates/change-record.md`.
1. Open the PR with scope, validation, risk, and rollback.
1. Watch the required checks after push.

## Incident Flow

1. Capture symptom, time window, workflow, and impacted tenant or component.
1. Identify the exact failing step or missing signal.
1. Reproduce locally when possible.
1. Patch the smallest failing contract.
1. Verify with local commands and a rerun.
1. Record root cause and prevention in `templates/incident-log.md`.

## Release Flow

1. Confirm merged changes since the last release.
1. Confirm generated docs and examples match the release state.
1. Run release validation or consume the candidate artifact in a smoke test.
1. Publish release metadata.
1. Watch post-release scheduled jobs and dependency automation.

## Exit Criteria For Maintenance Work

- The changed files match the requested scope.
- The source of truth is clear.
- Validation evidence is recorded.
- Rollback is documented.
- Any private adapter or environment-specific dependency is named in the PR, not
  hidden in a generic playbook.
