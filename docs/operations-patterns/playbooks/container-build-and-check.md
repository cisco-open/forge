# Playbook: Container Build And Check

## Goal

Build operational containers, tag them consistently, and verify that each image
can start before it is used by Forge automation.

## Use When

- Updating a runner container.
- Updating a tool container used by workflows.
- Rebuilding a quality or operations helper image.

## Inputs

- Container context path.
- Versioning rule.
- Target registry placeholder.
- Expected startup or smoke-test command.
- Optional security scan policy.

## Skeleton

1. Derive image version from branch, tag, input, or commit convention.
1. Build the image from the expected context.
1. Tag with version and immutable digest.
1. Run local smoke checks against the produced image.
1. Publish only after smoke checks pass.
1. Emit tag, digest, and check output in the workflow summary.

## Review Checklist

- Build context is scoped to the intended container.
- Secrets are not baked into the image.
- The check-image step uses the image that was just built.
- Tags are deterministic and traceable to source.
- Published digest is available for consumers.

## Definition Of Done

- Build succeeded.
- Smoke check succeeded.
- Digest or immutable reference is recorded.
- Consumers know which tag or digest to update.

## Common Failures

- Testing a stale image instead of the image from the current build.
- Using mutable tags as the only deployment reference.
- Hiding registry authentication inside shared docs.
