# Playbook: IaC Repository Operations

## Goal

Manage infrastructure repositories with predictable dry-run, apply, and
promotion behavior.

## Use When

- Updating environment configuration.
- Adding a new module or operational stack.
- Changing shared release versions.
- Adjusting promotion or regression coverage.

## Inputs

- Target environment.
- Changed paths.
- Module or stack dependency order.
- Dry-run command.
- Apply command protected by approval.

## Skeleton

1. Pull changed paths from the PR or dispatch input.
1. Discover affected units from repository structure.
1. Group units by dependency layer.
1. Run dry-run validation for pull requests.
1. Run apply only from protected branch or manual approval.
1. Aggregate all layer results into one final validation job.
1. Record dry-run or apply summaries per unit.

## Review Checklist

- New units are included in the reusable workflow path.
- Regression and promotion use the same reusable contract.
- Apply requires a protected environment or equivalent approval.
- Discovery excludes generated cache directories.
- Layers preserve dependency order.
- Final status does not depend on dynamic matrix names.

## Definition Of Done

- Pull requests dry-run all impacted units.
- Promotion applies the same units through the same contract.
- The PR includes changed units, validation commands, and rollback.

## Common Failures

- Adding a new stack that is never dry-run or applied.
- Patching only one caller while another caller uses the same reusable workflow.
- Treating generated units as static YAML entries.
