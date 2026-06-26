# Playbook: Dependency Automation

## Goal

Keep dependencies current through scheduled automation while preserving control
over validation, grouping, and private package access. This is the skeleton for
Renovate-style dependency automation.

## Use When

- Managing dependency update bots.
- Adding or changing dependency managers.
- Debugging failed dependency lookups.
- Grouping update PRs by risk.

## Inputs

- Dependency config.
- Repository list.
- Schedule.
- Authentication adapter for private package sources.
- Post-update validation commands.

## Skeleton

1. Run on schedule and manual dispatch.
1. Load dependency manager config from the repo.
1. Prepare private package access through a local adapter.
1. Run dependency discovery.
1. Open or update PRs.
1. Run post-update validation for supported change types.
1. Publish lookup failures and skipped updates.

## Review Checklist

- Dependency grouping matches reviewer capacity.
- Private package access is handled by an adapter, not copied into docs.
- Generated docs or lockfiles are updated when dependencies change.
- Failed lookups are visible.
- The bot does not bypass required checks.

## Definition Of Done

- Update PRs include validation.
- Failed dependency lookups are triaged.
- Config changes are tested with a dry-run where available.
- Reviewers know which update groups are low or high risk.

## Common Failures

- Treating no-result lookups as successful scans.
- Adding diagnostics that leak credentials or private paths.
- Letting dependency PRs pile up without grouping.
