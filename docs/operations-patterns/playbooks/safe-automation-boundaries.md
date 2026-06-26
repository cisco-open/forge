# Playbook: Safe Automation Boundaries

## Goal

Keep automation and agent-driven edits scoped, reversible, and easy to audit.

## Use When

- Asking an agent to edit the repo.
- Building a new maintenance automation.
- Running a bulk change across multiple files.

## Inputs

- User request.
- Target files or folders.
- Existing local changes.
- Allowed side effects.

## Checklist

1. State the intended scope before editing.
1. Read existing files and follow local patterns.
1. Preserve unrelated local changes.
1. Avoid destructive git operations unless explicitly requested.
1. Prefer additive docs or templates before runnable automation.
1. Validate only the changed surface.
1. Report what changed and what was left untouched.

## Definition Of Done

- The change set is scoped to the request.
- No unrelated files were modified.
- The audit trail names the commands or checks that mattered.

## Common Failures

- Broad refactors during a targeted maintenance request.
- Creating a parallel flow instead of adapting the existing one.
- Reverting user work while cleaning up.
