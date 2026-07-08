# Lambda Fixtures

## What This Is

This folder stores static sample payloads used by Lambda tests.

## Why It Is Used

Fixtures keep realistic event and sidecar shapes out of test bodies while still
letting tests assert against repo-owned examples. Any fixture committed here must
be safe: no real tenant secrets, tokens, installation IDs, or customer data.

## CI Execution

These files are consumed by `tests/lambdas` during the `Lambda Unit Tests`
workflow. The folder is not a standalone CI target.

## Local Execution

Run the tests that consume the fixtures, for example:

```bash
cd tests
uv run --project .. --locked --only-group lambda-tests pytest -q lambdas
```
