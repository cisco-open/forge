# Script Interfaces

Workflow examples call local scripts. Those scripts need stable arguments,
outputs, and exit codes so maintainers can run the same tasks locally and in
automation.

## Common Rules

- Every script supports `--help`.
- Every script uses `set -euo pipefail` or equivalent strict behavior.
- Every script accepts `--summary-file` when it produces human output.
- Every mutating script supports a read-only mode where practical.
- Exit code `0` means success.
- Exit code `1` means validation or execution failure.
- Exit code `2` means bad input or missing prerequisites.
- Exit code `3` means partial state requiring human review.

## `bake-image.sh`

```text
Usage:
  bake-image.sh <image-path> <version> [--summary-file <path>]

Outputs:
  image-id=<candidate-image-id>
  image-family=<family>
  image-version=<version>
```

Summary must include:

- image path
- version
- architecture
- build duration
- candidate image identifier
- warnings

## `test-runner-image.sh`

```text
Usage:
  test-runner-image.sh <candidate-image-id> [--summary-file <path>]
```

The test should prove:

- image boots or starts
- runner bootstrap completes
- a minimal command executes
- logs are available

## `run-deployment.sh`

```text
Usage:
  run-deployment.sh --command <dry-run|apply> --path <unit-path> --summary-file <path>
```

Rules:

- `dry-run` never changes remote state.
- `apply` requires approval from the caller.
- output includes changed, unchanged, skipped, and failed counts.

## `run-repository-factory.sh`

```text
Usage:
  run-repository-factory.sh --catalog <path> --mode <dry-run|apply> --summary-file <path>
```

Rules:

- validates catalog before action
- prevents accidental repository deletion by default
- reports create, update, unchanged, and manual follow-up items

## `scheduled-maintenance.sh`

```text
Usage:
  scheduled-maintenance.sh --target <target> --dry-run <true|false> --summary-file <path>
```

Rules:

- manual dispatch and scheduled runs call the same script
- dry-run is the default
- failures are listed with owner and next step

## `policy-hygiene.sh`

```text
Usage:
  policy-hygiene.sh --mode <scan|remediate> --policy-set <path> --summary-file <path>
```

Rules:

- `scan` is read-only
- `remediate` requires approval
- exemptions include owner and expiration

## `run-dependency-bot.sh`

```text
Usage:
  run-dependency-bot.sh --config <path> --summary-file <path>
```

Rules:

- failed lookups are reported as warnings or failures
- generated file updates are visible
- private package access stays behind an adapter

## `migrate-workload.sh`

```text
Usage:
  migrate-workload.sh --workload <name> --target <target> --summary-file <path>
```

Rules:

- migration is idempotent
- each workload emits a checkpoint
- partial state exits with code `3`
