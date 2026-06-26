# Workflow Summary Examples

Good summaries let operators understand a workflow without reading raw logs.
Every automation family should write a sanitized Markdown summary.

## Image Factory Summary

```markdown
# Image Factory Summary

- Version: 20260626-a1b2c3d4
- Trigger: pull_request
- Final status: success

## Build Matrix

| Family | Version | Arch | Result | Candidate |
| --- | --- | --- | --- | --- |
| linux | 24.04 | amd64 | success | <candidate-image-id> |
| linux | 24.04 | arm64 | skipped | skip flag |

## Smoke Tests

| Candidate | Test | Result |
| --- | --- | --- |
| <candidate-image-id> | boot-and-run-command | success |

## Follow-Up

- No follow-up required.
```

## Repository Factory Summary

```markdown
# Repository Factory Summary

- Catalog: config/repositories.yaml
- Mode: dry-run
- Final status: success

## Planned Changes

| Repository | Action | Notes |
| --- | --- | --- |
| forge-runner-images | create | from template |
| forge-ops-maintenance | update | required checks changed |

## Manual Follow-Up

| Repository | Follow-Up | Owner |
| --- | --- | --- |
| forge-runner-images | install app or secret placeholder | <owner> |
```

## Scheduled Maintenance Summary

```markdown
# Scheduled Maintenance Summary

- Mode: dry-run
- Target: all
- Final status: warning

## Results

| Target | Action | Result | Next Step |
| --- | --- | --- | --- |
| stale-prs | label | success | none |
| old-runs | cleanup | skipped | dry-run only |
| report-page | publish | failed | rerun after permissions fix |
```

## Policy Hygiene Summary

```markdown
# Policy Hygiene Summary

- Policy set: policies/default
- Mode: scan
- Final status: failed

## Findings

| Severity | Policy | Resource | Owner | Next Step |
| --- | --- | --- | --- | --- |
| high | expired-temporary-resource | <resource-id> | <owner> | approve remediation |
| medium | missing-owner-tag | <resource-id> | unknown | assign owner |

## Exemptions

| Policy | Resource | Expires | Owner |
| --- | --- | --- | --- |
| missing-owner-tag | <resource-id> | 2026-07-31 | <owner> |
```

## Dependency Automation Summary

```markdown
# Dependency Automation Summary

- Config: config/dependencies.json
- Final status: warning

## Updates

| Group | PR | Result |
| --- | --- | --- |
| github-actions | <pr-link> | opened |
| container-images | <pr-link> | updated |

## Failed Lookups

| Manager | Package | Reason |
| --- | --- | --- |
| image | <package> | private source unavailable |
```

## Migration Summary

```markdown
# Runtime Migration Summary

- Environment: prod
- Active target before: active-a
- Inactive target before: inactive-b
- Final status: success

## Phases

| Phase | Result | Checkpoint |
| --- | --- | --- |
| discovery | success | runtime-state.json |
| disable-workflows | success | workflows-disabled |
| recreate-inactive | success | inactive-ready |
| move-to-inactive | success | workloads-on-inactive |
| recreate-active | success | active-ready |
| move-to-active | success | workloads-on-active |
| enable-workflows | success | workflows-enabled |
```
