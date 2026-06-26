# Playbook: Workflow Change Safety

## Goal

Change automation behavior without surprising reviewers or breaking protected
paths.

## Use When

- Editing workflow triggers.
- Adding or removing workflow jobs.
- Changing permissions, concurrency, environments, or reusable workflow inputs.

## Inputs

- Target workflow files.
- Expected behavior before and after the change.
- Required checks for protected branches.

## Checklist

1. Identify the workflow entry point and any reusable workflow it calls.
1. Review trigger, path filter, permissions, concurrency, and environment gates.
1. Keep private credential setup inside local adapters.
1. Validate workflow syntax and repository hooks.
1. Explain the behavior change in the PR.
1. Confirm branch protection still points at stable required checks.

## Definition Of Done

- The workflow diff is minimal and reviewable.
- The validation path is documented.
- Apply, publish, or destructive steps remain behind explicit gates.

## Common Failures

- Making a workflow reusable but forgetting to document its inputs.
- Requiring dynamic matrix job names in branch protection.
- Adding broad write permissions for a single commenting or publishing step.
