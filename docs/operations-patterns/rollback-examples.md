# Rollback Examples

Every automation family needs a rollback shape before it is used in production.

## Image Rollback

Use when a newly baked image fails after publication.

1. Stop promotion of the candidate image.
1. Repoint consumers to the previous known-good image identifier.
1. Open a fix PR against the image recipe.
1. Re-run image factory with smoke tests.
1. Publish a replacement only after downstream consumer validation.

Rollback record:

```markdown
## Image Rollback

- Bad candidate:
- Previous known-good:
- Consumers reverted:
- Validation after revert:
- Follow-up PR:
```

## Container Rollback

1. Repoint workflow or config to the previous immutable image digest.
1. Re-run the check-image job.
1. Disable scheduled use of the bad tag if needed.
1. Open a fix PR.

## Repository Catalog Rollback

1. Revert the catalog entry change.
1. Dry-run repository factory.
1. Confirm the dry-run restores intended settings only.
1. Apply through the protected path.
1. Verify branch protection and required checks.

Do not delete repositories automatically unless the deletion was explicitly
approved and documented.

## Declared-State Apply Rollback

1. Identify the unit path and last successful run.
1. Revert the declared-state change.
1. Run dry-run for the unit.
1. Apply through the protected path.
1. Confirm runtime state matches the previous intended state.

## Scheduled Job Rollback

1. Disable the schedule or set dry-run mode.
1. Revert the job config or target selector.
1. Manually dispatch the job in dry-run mode.
1. Re-enable the schedule after the summary is clean.

## Policy Remediation Rollback

1. Stop additional remediation runs.
1. Identify remediated resources from the summary.
1. Restore only resources that were changed by the remediation run.
1. Add or update exemption if the policy was too broad.
1. Re-run scan mode.

## Dependency Update Rollback

1. Revert the dependency PR or restore the previous lockfile.
1. Re-run generated docs or lockfile checks.
1. Pause or reconfigure the update rule if the package source is unstable.
1. Reopen the update with a smaller group if needed.

## Migration Rollback

1. Stop at the latest successful checkpoint.
1. Confirm workflows are disabled if migration state is split.
1. Move workloads back to the last known-good target.
1. Re-enable workflows only after workload health is verified.
1. Record the checkpoint and failed phase.
