# Test Support Helpers

## What This Is

`tests/support` contains shared helper code for pytest suites. It is not
production code and is not a standalone test suite.

## Why It Is Used

The helpers load real Lambda handler modules from their repo paths, build
realistic API Gateway events, sign GitHub webhook payloads, and keep import
behavior close to the Lambda runtime.

## CI Execution

This package is imported by the `Lambda Unit Tests` workflow. CI does not run it
directly.

## Local Execution

Run a suite that imports it:

```bash
cd tests
uv run --project .. --locked --only-group lambda-tests pytest -q lambdas
```

Do not put test assertions here. Add assertions to the consuming suite so pytest
reports behavior clearly.
