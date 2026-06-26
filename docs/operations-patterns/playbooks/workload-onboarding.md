# Playbook: Workload Onboarding

## Goal

Add or update a tenant, workload, or integration through a repeatable reviewable
process.

## Use When

- A team requests new Forge capacity.
- An existing workload needs a new runner class or integration.
- A config was removed and must be restored.

## Inputs

- Request record or issue.
- Target environment and ownership.
- Required runner type, access model, and observability needs.
- Existing baseline configuration to compare against.

## Checklist

1. Read the request and extract requirements.
1. Confirm the target path and naming convention.
1. Compare with a known-good baseline.
1. Add only the required config fields.
1. Validate syntax and structure.
1. Run dry-run validation for the impacted path.
1. Record expected access, logging, and rollback behavior.

## Definition Of Done

- The request maps to explicit config changes.
- New files match the repository path convention.
- Validation shows the intended impact only.
- The PR names owner, scope, risk, and rollback.

## Common Failures

- Inferring requirements from memory instead of the request record.
- Mixing onboarding with unrelated cleanup.
- Copying secret material into tracked files.
