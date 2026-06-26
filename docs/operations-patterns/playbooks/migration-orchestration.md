# Playbook: Migration Orchestration

## Goal

Move workloads through a multi-phase migration with clear checkpoints and
rollback points.

## Use When

- Rebuilding active and inactive clusters.
- Moving tenants between active states.
- Recreating shared runtime infrastructure.
- Coordinating maintenance that must temporarily disable normal workflows.

## Inputs

- Active and inactive target names.
- Tenant or workload matrix.
- Disable and enable workflow controls.
- Phase order.
- Rollback checkpoint.

## Skeleton

1. Discover active and inactive state.
1. Disable competing scheduled or promotion workflows.
1. Destroy or drain inactive target.
1. Recreate inactive target.
1. Move workloads to inactive target.
1. Destroy or drain old active target.
1. Recreate active target.
1. Move workloads back to active target.
1. Scale down inactive target.
1. Re-enable normal workflows.
1. Publish phase summary and rollback notes.

## Review Checklist

- Discovery reflects current state before phase one.
- Every phase has a dependency on the previous phase.
- Workload matrix is visible.
- Competing automations are disabled only for the maintenance window.
- Rollback or resume point is clear after each phase.

## Definition Of Done

- All phases completed or stopped at a documented checkpoint.
- Normal workflows are re-enabled.
- Summary shows workload movement and final state.
- Any follow-up is tracked.

## Common Failures

- Running migration while normal automation is still active.
- Hiding all phases inside one opaque job.
- Lacking a clear resume point after partial failure.
