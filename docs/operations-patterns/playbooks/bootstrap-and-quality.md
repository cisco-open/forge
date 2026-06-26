# Playbook: Bootstrap And Quality Gate

## Goal

Start Forge work from a known local baseline and pass the repository quality
gate before review.

## Use When

- Starting work in a repo or unfamiliar area.
- Preparing a PR.
- Reproducing a failing quality check.

## Inputs

- Repository path.
- Target branch.
- Current changed files.

## Checklist

1. Confirm the current branch and worktree status.
1. Identify existing local changes before editing.
1. Install or refresh repo-local hooks if needed.
1. Run the repository quality command.
1. Fix failures in the smallest possible patch.
1. Rerun the same command until it passes.
1. Record the command and result in the change record.

## Definition Of Done

- The quality gate passes or the remaining blocker is documented.
- Existing unrelated local changes were not reverted or staged accidentally.
- The PR notes include validation evidence.

## Common Failures

- Running checks from the wrong directory.
- Fixing generated files by hand.
- Staging unrelated local edits.
