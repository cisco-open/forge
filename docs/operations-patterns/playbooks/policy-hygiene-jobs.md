# Playbook: Policy Hygiene Jobs

## Goal

Run recurring policy checks or remediations that keep the Forge environment
clean without requiring manual scans. This is the skeleton for Custodian-style
jobs, regardless of which policy engine runs behind the local adapter.

## Use When

- Checking resource drift against policy.
- Enforcing retention, tagging, ownership, or lifecycle rules.
- Producing hygiene reports for operators.

## Inputs

- Policy set.
- Target scope.
- Read-only versus remediation mode.
- Exemption list.
- Summary destination.

## Skeleton

1. Load the policy set from the repository.
1. Resolve target scope from input or schedule.
1. Run read-only scan by default.
1. Run remediation only when explicitly approved.
1. Publish findings with severity, owner, and resource placeholder.
1. Track exemptions and expiration dates.

## Review Checklist

- Default mode is read-only.
- Remediation is gated and reversible.
- Exemptions are explicit and reviewed.
- Findings include enough context for the owner to act.
- The policy job has a manual rerun path.

## Definition Of Done

- Findings are visible.
- Remediations are auditable.
- Exemptions are not permanent by accident.
- Operators can rerun the job without editing workflow code.

## Common Failures

- Treating policy scan failures as noise.
- Applying remediation without an approval gate.
- Publishing findings without owners or next steps.
