# Quality Gate Tests

## What This Is

`tests/quality` contains meta-tests that verify the repository keeps important
quality gates wired.

## Why It Is Used

These tests protect the automation itself. They assert that every Terraform
module has a specific native OpenTofu test file, that security and SCA checks
stay in pre-commit, that Docker images use root locked dependencies, and that
mutation tests remain connected to CI.

## CI Execution

The `Quality Gates` workflow runs this folder through a dedicated
`Automation gate tests` job:

```bash
cd tests
uv run --project .. --locked --only-group lambda-tests pytest -q quality
```

The tests intentionally inspect repository files and workflow text; they do not
contact AWS or run Docker.

## Local Execution

Run:

```bash
cd tests
uv run --project .. --locked --only-group lambda-tests pytest -q quality
```

If this suite fails, treat the failure as a missing gate or stale assertion and
fix the underlying repo wiring rather than deleting the check.
