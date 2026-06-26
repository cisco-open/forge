# Playbook: PR Readiness

## Goal

Prepare a PR that reviewers can approve without reconstructing the whole
investigation.

## Use When

- Before opening a PR.
- Before requesting review after new commits.
- When replacing a weak PR description.

## Inputs

- Final diff.
- Validation commands and outputs.
- Known risk and rollback path.

## Checklist

1. Confirm the changed files match the request.
1. Summarize the problem in one or two sentences.
1. List the actual behavior change.
1. Include validation commands and results.
1. Call out risk, impact, and rollback.
1. Mention anything intentionally not changed.

## Definition Of Done

- The PR body has scope, validation, risk, and rollback.
- No unverified validation claims are included.
- Reviewers can tell what changed and why.

## Common Failures

- Filling a PR template with generic wording.
- Claiming tests passed when they were not run.
- Hiding unrelated changes in a broad summary.
