# Lambda Tests

## What This Is

`tests/lambdas` contains pytest coverage for Forge first-party Lambda handlers.
The suite includes unit, security, isolation, error-handling, idempotency, and
deterministic payload property tests.

## Why It Is Used

Forge Lambda code sits on tenant and trust boundaries. These tests exercise
observable handler behavior: accepted and rejected inputs, AWS side effects in
moto, SQS retry and DLQ behavior, STS or SSM failure paths, webhook signature
validation, log hygiene, and cross-tenant isolation.

## CI Execution

The `Lambda Unit Tests` workflow runs this folder from `tests/` with the pinned
`lambda-tests` dependency group in `pyproject.toml`:

```bash
uv run --project .. --locked --only-group lambda-tests pytest -q lambdas --junitxml=pytest-results.xml
```

The workflow also uploads `coverage.xml` and `pytest-results.xml` as artifacts.

## Local Execution

Run the Lambda suite with:

```bash
cd tests
uv run --project .. --locked --only-group lambda-tests pytest -q lambdas
```

Useful focused runs:

```bash
cd tests
uv run --project .. --locked --only-group lambda-tests pytest -q lambdas/webhook_signature_test.py
uv run --project .. --locked --only-group lambda-tests pytest -q -m security
uv run --project .. --locked --only-group lambda-tests pytest -q -m fuzz
```

The suite must not use real AWS. Shared fixtures force dummy credentials and use
moto for AWS APIs.
