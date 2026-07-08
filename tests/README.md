# Forge Test Suites

This directory contains Forge's repo-level tests. They are split by execution
model so CI can keep AWS-free checks fast and deterministic:

| Folder      | Purpose                                                                                              | CI lane                  | Local command                                                                           |
| ----------- | ---------------------------------------------------------------------------------------------------- | ------------------------ | --------------------------------------------------------------------------------------- |
| `lambdas/`  | Unit, security, isolation, and deterministic payload property tests for first-party Lambda handlers. | `Lambda Unit Tests`      | `cd tests && uv run --project .. --locked --only-group lambda-tests pytest -q lambdas`  |
| `iac/`      | Offline Python contract tests for Terraform-to-Lambda wiring.                                        | `IaC Policy`             | `cd tests && uv run --project .. --locked --only-group lambda-tests pytest -q iac`      |
| `quality/`  | Meta-tests that enforce required automation and quality gates.                                       | `Quality Gates`          | `cd tests && uv run --project .. --locked --only-group lambda-tests pytest -q quality`  |
| `mutation/` | Deterministic source-mutation tests for critical security boundaries.                                | `Quality Gates`          | `cd tests && uv run --project .. --locked --only-group lambda-tests pytest -q mutation` |
| `smoke/`    | MiniStack smoke tests for local AWS-like plumbing and real Lambda execution.                         | `MiniStack Smoke`        | `cd tests/smoke && make up && make smoke`                                               |
| `tofu/`     | Shared helper modules consumed by module-local `.tftest.hcl` files.                                  | `IaC Policy`             | Run `tofu test` from a module that references the helper.                               |
| `support/`  | Shared pytest support code, not a test suite by itself.                                              | Imported by pytest lanes | Imported by tests.                                                                      |

The root pytest config is `tests/pytest.ini`. It deliberately excludes
`tests/smoke` because MiniStack tests need a running emulator and, for Lambda
execution, Docker. CI runs named jobs for each suite. The repo-level local
pytest command for all non-smoke Python suites is:

```bash
cd tests
uv run --project .. --locked --only-group lambda-tests pytest -q
```

The suites must not require real AWS credentials. Unit and contract tests use
moto or offline source inspection. MiniStack tests use dummy credentials pointed
at `http://localhost:4566`.
