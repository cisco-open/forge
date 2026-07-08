# Offline IaC Contract Tests

## What This Is

`tests/iac` contains Python contract tests that inspect Terraform and Lambda
source files without initializing providers or contacting AWS.

## Why It Is Used

These tests pin Forge contracts that cross the HCL/Python boundary: Lambda
environment variables, event-source wiring, queue and bucket assumptions, and
other module-to-handler interfaces. They catch changes where Terraform stops
providing something the handler requires, or where a handler starts requiring
something Terraform does not set.

## CI Execution

The `IaC Policy` workflow runs this folder through a dedicated
`Offline IaC contract tests` job from `tests/`:

```bash
uv run --project .. --locked --only-group lambda-tests pytest -q iac
```

## Local Execution

Run only these contracts with:

```bash
cd tests
uv run --project .. --locked --only-group lambda-tests pytest -q iac
```

These tests are hermetic. They do not need Docker, cloud credentials, Terraform
providers, or network access.
