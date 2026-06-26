# Playbook: Image Bake And Test

## Goal

Bake runner images in a repeatable matrix, test the produced images, and expose
one stable PR validation result.

## Use When

- Updating base operating system images.
- Adding or removing runner tools.
- Changing hardening, bootstrap, or runtime configuration.
- Promoting an image candidate into downstream runner builds.

## Inputs

- Image family list.
- Operating system, version, and architecture matrix.
- Versioning rule.
- Optional skip flags for expensive matrix entries.
- Smoke test commands.
- Downstream image or runner build that consumes the base image.

## Skeleton

1. Compute image version.
1. Parse skip flags from PR title, commit message, or manual input.
1. Build each requested image family and architecture.
1. Collect only successfully built images into a test matrix.
1. Smoke-test each image with a minimal runner workload.
1. Optionally build a downstream image from the candidate base image.
1. Run one final PR validation job that evaluates all required jobs.
1. Publish image identifiers and smoke-test summaries.

## Review Checklist

- Build matrix matches the changed image files.
- Skip flags cannot hide required security or release validation.
- Smoke tests prove the runner can boot and execute a basic job.
- Downstream consumers are tested when a base image changes.
- Final validation is stable enough for branch protection.
- Image identifiers are recorded without exposing private registry details.

## Definition Of Done

- Candidate image builds completed or intentional skips are documented.
- Smoke tests passed for each required candidate.
- Downstream consumer test passed when applicable.
- PR includes build matrix, skipped entries, image identifiers, and rollback.

## Common Failures

- Publishing an image that was built but never boot-tested.
- Using dynamic matrix job names as required checks.
- Letting skip flags bypass all meaningful validation.
- Losing the image identifier needed for downstream testing.
