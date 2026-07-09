# MiniStack Smoke Test Modules

## What This Is

This folder contains the pytest modules executed by the `tests/smoke` suite.

## Why It Is Used

The tests are split by smoke depth:

- `smoke_test.py` and `liveness_test.py` check fast AWS-like service liveness.
- `lambda_smoke_test.py`, `lambda_guard_exec_test.py`, and
  `validate_signature_exec_test.py` exercise real Lambda execution in MiniStack.
- `conftest.py` owns emulator readiness behavior and dummy AWS clients.

## CI Execution

The parent `MiniStack Smoke` workflow runs from `tests/smoke`:

```bash
uv run --project ../.. --locked --only-group smoke-tests pytest -m smoke -q
uv run --project ../.. --locked --only-group smoke-tests pytest -m lambda_exec -q
```

The `lambda_exec` marker requires Docker because MiniStack starts Lambda
containers.

The `smoke` role-chain liveness test creates and assumes a dummy IAM role inside
MiniStack. It does not require `FORGE_SMOKE_ASSUME_ROLE_ARN` or live AWS access.

## Local Execution

Use the parent directory Makefile:

```bash
cd tests/smoke
make up
make smoke
make lambda
make down
```

Local runs skip when MiniStack is unavailable unless
`FORGE_REQUIRE_MINISTACK=1` is set.
