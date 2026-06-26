# Playbook: Scheduled Jobs

## Goal

Run recurring operational hygiene with clear ownership, locking, and summaries.
This is the skeleton for cron-style jobs that operate Forge without requiring a
human to press a button each time.

## Use When

- Tagging or labeling stale pull requests.
- Publishing generated reports or pages.
- Running periodic smoke tests.
- Checking inactive resources or stale state.

## Inputs

- Schedule.
- Manual dispatch inputs.
- Target scope.
- Lock or concurrency key.
- Summary output format.

## Skeleton

1. Pair schedule with manual dispatch.
1. Acquire a workflow-level concurrency lock.
1. Load targets from the source of truth.
1. Run the smallest scoped job.
1. Emit changed, skipped, and failed targets.
1. Fail when automation cannot prove the final state.

## Review Checklist

- Schedule cadence matches operational need.
- Manual dispatch can run the same logic on demand.
- Permissions are minimal.
- The job cannot overlap with itself.
- Summary tells maintainers what happened without opening every log line.

## Definition Of Done

- Job runs on schedule and on demand.
- Summary is readable.
- Failures are actionable.
- Mutating behavior is documented and scoped.

## Common Failures

- Scheduled jobs that silently skip work.
- Jobs that overlap and race on the same resources.
- No manual dispatch path for urgent reruns.
