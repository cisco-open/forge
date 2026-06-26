# Playbook: CI Failure Triage

## Goal

Move from a failing check to a targeted fix with a short evidence trail.

## Use When

- A PR check fails.
- A scheduled workflow fails.
- A workflow rerun fails differently from the original failure.

## Inputs

- Failing workflow name.
- Failing job and step.
- Relevant log excerpt.
- Changed files in the PR or recent commit.

## Checklist

1. Capture the exact failing job, step, and error.
1. Check whether the failure is from the changed files or shared tooling.
1. Reproduce locally with the closest equivalent command.
1. Patch the smallest root cause.
1. Rerun the local command.
1. Push or rerun CI only after local evidence is collected.
1. Record symptom, cause, fix, and validation.

## Definition Of Done

- The failing check passes or the blocker is clearly external.
- The fix explains why the failure happened.
- The PR includes validation and residual risk.

## Common Failures

- Rerunning CI repeatedly without local reproduction.
- Fixing an earlier failure after the check moved to a new failing step.
- Treating a workflow contract mismatch as a transient error.
