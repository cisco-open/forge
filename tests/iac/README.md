# Offline IaC Contract Tests

## What This Is

`tests/iac` contains Python contract tests that inspect Terraform and Lambda
source files and exercise infrastructure helper scripts with fake CLIs. They do
not initialize providers or contact AWS.

## Why It Is Used

These tests pin Forge contracts that cross source boundaries: Lambda environment
variables, event-source wiring, queue and bucket assumptions, module-to-handler
interfaces, and local provisioning-script behavior. They catch changes where
Terraform stops providing something a helper requires or a helper no longer
handles its lifecycle edge cases safely.

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
