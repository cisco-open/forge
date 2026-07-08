# Mutation Tests

## What This Is

`tests/mutation` contains deterministic mutation tests for high-risk security
logic. The suite mutates critical Lambda boundaries and proves weakened
behavior is observable.

## Why It Is Used

Line coverage alone can say a handler ran; mutation tests prove that the tests
fail when critical checks are removed or weakened. This is reserved for small,
security-sensitive boundaries where the extra runtime is justified.

Current targets:

| File                                       | Boundary guarded                                      |
| ------------------------------------------ | ----------------------------------------------------- |
| `webhook_signature_mutation_test.py`       | GitHub webhook HMAC-SHA256 verification.              |
| `redrive_deadletter_mutation_test.py`      | DLQ source selection and redrive error reporting.     |
| `trust_boundary_mutation_test.py`          | Trust policy, delay bounds, and tenant session scope. |
| `job_log_archiver_mutation_test.py`        | Archiver failure propagation and metadata limits.     |
| `splunk_stuck_dispatcher_mutation_test.py` | Splunk payload validation, dedupe, and token checks.  |
| `github_app_runner_group_mutation_test.py` | SSM decryption and selected repository propagation.   |

## CI Execution

The `Quality Gates` workflow runs this folder directly:

```bash
cd tests
uv run --project .. --locked --only-group lambda-tests pytest -q mutation
```

## Local Execution

Run:

```bash
cd tests
uv run --project .. --locked --only-group lambda-tests pytest -q mutation
```

Keep mutation cases deterministic. Do not use live network calls, real AWS, wall
clock timing, or unseeded randomness.
