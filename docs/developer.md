# Developer Test Guide

Forge separates tests by execution model so developers can choose the narrowest
suite that proves a change without requiring live infrastructure.

| Suite                            | Purpose                                                                                   | External requirements                                                    |
| -------------------------------- | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `tests/lambdas`                  | First-party Lambda behavior, security, isolation, error handling, and payload properties. | None; uses pytest and moto.                                              |
| `tests/iac`                      | Contracts crossing the Terraform-to-Lambda boundary.                                      | None; inspects source offline.                                           |
| Module-local `.tftest.hcl` files | Terraform module structure, public interfaces, planned behavior, and validation.          | OpenTofu and initialized provider schemas; no live AWS for mocked tests. |
| `tests/mutation`                 | Proves critical security tests detect intentionally weakened code.                        | None; deterministic source mutation.                                     |
| `tests/quality`                  | Protects repository automation and required quality gates.                                | None; inspects repository files offline.                                 |
| `tests/smoke`                    | Checks AWS-like service wiring and selected real Lambda execution in MiniStack.           | MiniStack; Docker is also required for Lambda execution.                 |
| `tests/support`                  | Shared pytest helpers and realistic test-event builders.                                  | Not run directly.                                                        |

None of the repository test suites should contact live AWS. Use a real
environment only through a separately reviewed deployment or acceptance-test
process.

## Choosing a suite

Use the closest boundary to the change:

| Change or risk                                                                          | Primary suite                                             |
| --------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| Lambda handler logic, error handling, retries, logging, or AWS side effects             | Lambda tests                                              |
| Tenant isolation, webhook validation, or another Lambda security boundary               | Lambda tests, plus mutation tests for a critical boundary |
| Terraform stops supplying an environment variable or event source required by a handler | Offline IaC contracts                                     |
| Terraform module resources, inputs, outputs, policies, or validation change             | Native OpenTofu tests                                     |
| A required CI, security, test, or dependency gate could be removed                      | Quality tests                                             |
| Local AWS-like service plumbing or Lambda packaging/execution could be broken           | MiniStack smoke tests                                     |

A change can cross several boundaries. For example, adding a Lambda environment
variable can require a handler unit test, an offline IaC contract, and a native
OpenTofu behavior test.

## Lambda tests

`tests/lambdas` contains pytest tests for first-party Lambda handlers. These are
the default tests for handler behavior because they are fast, deterministic,
and do not require Docker or a running emulator.

Use Lambda tests for:

- accepted and rejected event payloads;
- AWS calls and side effects represented through moto;
- SQS retry, partial-batch failure, and DLQ behavior;
- STS, SSM, and other dependency failure paths;
- webhook signature validation;
- idempotency and duplicate delivery;
- secret and log hygiene;
- cross-tenant isolation;
- deterministic payload property tests.

The shared fixtures in `tests/conftest.py` force dummy AWS credentials. Tests
that use AWS APIs enter the `aws` fixture so moto intercepts those calls. Load a
handler only after the required fixture and environment are active because some
handlers create clients during module import.

Run the complete Lambda suite:

```bash
cd tests
uv run --project .. --locked --only-group lambda-tests pytest -q lambdas
```

Run one file or a marked subset:

```bash
cd tests
uv run --project .. --locked --only-group lambda-tests \
  pytest -q lambdas/webhook_signature_test.py
uv run --project .. --locked --only-group lambda-tests \
  pytest -q -m security
uv run --project .. --locked --only-group lambda-tests \
  pytest -q -m isolation
uv run --project .. --locked --only-group lambda-tests \
  pytest -q -m fuzz
```

Assert observable handler outcomes rather than implementation details. Check
the returned payload or batch failures, the expected moto resource state, and
relevant logs. Explicitly exercise dependency errors and tenant-boundary
failures when the handler owns those decisions.

## Offline IaC contract tests

`tests/iac` contains Python tests for contracts that cross the Terraform and
Lambda source boundary. They catch cases where:

- Terraform stops setting an environment variable the handler reads;
- event-source settings no longer match handler batch behavior;
- queue, bucket, or resource names drift between HCL and Python;
- a handler starts depending on configuration Terraform does not provide.

These are offline source-contract tests. They do not initialize providers,
contact AWS, or require Docker.

Run them with:

```bash
cd tests
uv run --project .. --locked --only-group lambda-tests pytest -q iac
```

Use a native OpenTofu test when the assertion is entirely about Terraform. Use
a Lambda test when the assertion is entirely about handler behavior. Use an
offline IaC contract when the risk exists specifically at the boundary between
the two.

## Terraform and OpenTofu tests

Forge uses the native OpenTofu test framework to test Terraform modules. Test
files use the `.tftest.hcl` extension and live in a `tests` directory beside the
module they exercise:

```text
modules/<category>/<module>/
├── main.tf
├── outputs.tf
├── variables.tf
└── tests/
    ├── <module>_source_inventory.tftest.hcl
    ├── <module>_interface_contract.tftest.hcl
    └── <module>_behavior.tftest.hcl
```

OpenTofu recognizes every file ending in `.tftest.hcl`. The suffix before that
extension is a Forge convention that identifies the purpose of the test:

| Test type                         | Required                                 | Purpose                                                                   |
| --------------------------------- | ---------------------------------------- | ------------------------------------------------------------------------- |
| `*_source_inventory.tftest.hcl`   | Once per module                          | Protect important Terraform blocks and structural source contracts.       |
| `*_interface_contract.tftest.hcl` | Once per module                          | Protect the complete public input and output interface.                   |
| `*_behavior.tftest.hcl`           | When the module has behavior to exercise | Verify planned resources, wiring, policies, outputs, and input rejection. |

Keep these responsibilities separate. A source-inventory test should not become
a substitute for a behavior assertion, and a behavior test should not duplicate
the complete public-interface inventory.

### Source-inventory tests

A source-inventory test protects Terraform constructs that must remain present
in a module. Examples include a required resource, provider block, output,
policy condition, environment variable, or event-source declaration.

These tests call the shared `tests/tofu/module_contract` helper. The helper reads
the module's Terraform files and reports any expected source literals that are
missing:

```hcl
run "helpers_ecr_source_inventory" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"aws_ecr_repository\" \"ops_container_repository\"",
      "resource \"aws_ecr_lifecycle_policy\" \"ops_cleanup_policy\"",
      "output \"ops_container_repository_names\"",
      "provider \"aws\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 4
    error_message = "Source inventory must keep 4 module-specific Terraform blocks pinned."
  }
}
```

Use this test type when the presence of a Terraform construct is itself part of
the module contract. Pin module-specific constructs rather than generic syntax
that appears in nearly every module.

Source-inventory tests inspect text. They prove that a literal remains present,
but they do not prove that the resulting plan behaves correctly. Refactoring or
reformatting a pinned construct can therefore require an intentional test
update even when behavior is unchanged.

### Interface-contract tests

An interface-contract test protects how callers consume a module. It calls the
shared `tests/tofu/module_interface_contract` helper to compare the module's
declared public interface with an explicit expected interface.

Each interface contract pins:

- every input variable name;
- every output name;
- important variable types, defaults, descriptions, and validation rules;
- sensitive declarations where applicable;
- important output value expressions.

The test asserts both sides of the comparison:

```hcl
assert {
  condition     = length(output.missing_input_variables) == 0
  error_message = "Interface contract is missing input variables: ${join(", ", output.missing_input_variables)}"
}

assert {
  condition     = length(output.unexpected_input_variables) == 0
  error_message = "Interface contract has unexpected input variables: ${join(", ", output.unexpected_input_variables)}"
}
```

Checking for both missing and unexpected names prevents accidental interface
expansion as well as accidental removal. Adding a variable or output is an API
change and must be reflected deliberately in the contract.

Use this test type for the module's public API. Do not use it to pin internal
resource behavior; that belongs in a behavior test.

### Behavior tests

A behavior test exercises the module under test and asserts properties of its
plan or test state. It is the appropriate test type for:

- resource arguments derived from module inputs;
- conditional creation using `count` or `for_each`;
- tag and policy composition;
- resource-to-resource wiring;
- module outputs;
- input validation and other expected failures.

Provider-backed modules should normally use a mock provider and `command = plan`:

```hcl
mock_provider "aws" {}

variables {
  aws_region = "us-east-1"
  tags = {
    Environment = "test"
  }
}

run "creates_expected_repository" {
  command = plan

  assert {
    condition = (
      aws_ecr_repository.example.name == "forge/example"
      && aws_ecr_repository.example.tags.Environment == "test"
    )
    error_message = "The repository must preserve its configured name and tags."
  }
}
```

`mock_provider` prevents provider create and read operations. `command = plan`
keeps the test focused on the configuration OpenTofu intends to apply. Together
they make the normal Forge behavior test deterministic and independent of AWS
credentials.

Use `expect_failures` to prove that invalid configuration is rejected by the
intended validation rule:

```hcl
run "rejects_invalid_value" {
  command = plan

  variables {
    mode = "invalid"
  }

  expect_failures = [
    var.mode,
  ]
}
```

Do not treat an arbitrary failed plan as a successful negative test. Reference
the variable, resource, output, precondition, or postcondition expected to fail.

OpenTofu defaults a `run` block to `command = apply` when no command is
specified. An apply test can create real infrastructure when its providers are
not mocked. Use `apply` only when the behavior cannot be proven from a plan,
keep all external interactions controlled, and make the reason clear in the
test.

### Choosing the Terraform test type

Use the narrowest test that proves the contract:

| Change or risk                                                          | Test type                       |
| ----------------------------------------------------------------------- | ------------------------------- |
| A required resource or policy construct could be deleted                | Source inventory                |
| An input, output, type, default, validation, or sensitivity could drift | Interface contract              |
| An input must produce a specific resource argument or output            | Behavior                        |
| A conditional branch must create or omit resources                      | Behavior                        |
| Invalid input must be rejected                                          | Behavior with `expect_failures` |
| AWS must accept an API call or services must interact at runtime        | Not covered by this framework   |

A change can require updates to more than one type. For example, adding a new
validated input normally changes the interface contract and should also gain a
behavior test showing how the input affects the plan.

### Writing a Terraform test

1. Put the test in the module's `tests` directory.
1. Use the suffix matching its responsibility.
1. Prefer file-level `variables` for shared valid inputs.
1. Override variables inside a `run` block only for that scenario.
1. Give each `run` block a name describing the expected behavior.
1. Use `command = plan` unless an apply is specifically required.
1. Mock provider-backed resources so the test does not require cloud
   credentials.
1. Assert a meaningful contract rather than only checking that planning
   succeeds.
1. Write an error message that tells the developer which contract changed.
1. Run formatting, initialization, validation, and the module tests locally.

Keep assertions focused. When unrelated conditions would produce different
remediation, split them into separate assertions so a failure identifies the
broken contract.

### Running Terraform tests locally

Initialize the module before its first test run or after provider requirements
change:

```bash
tofu -chdir=modules/helpers/ecr init -backend=false -input=false
```

Run every test for the module:

```bash
tofu -chdir=modules/helpers/ecr test -no-color
```

Run one test file:

```bash
tofu -chdir=modules/helpers/ecr test \
  -filter=tests/ecr_behavior.tftest.hcl \
  -no-color
```

Use `-verbose` when the planned values or test state are needed to diagnose a
failure:

```bash
tofu -chdir=modules/helpers/ecr test -verbose -no-color
```

Before submitting a Terraform test change, also run:

```bash
tofu fmt -check -recursive
tofu -chdir=modules/helpers/ecr validate -no-color
tflint --chdir=modules/helpers/ecr \
  --disable-rule=terraform_required_providers \
  --no-color
```

Replace `modules/helpers/ecr` with the module being changed.

### Terraform CI and repository enforcement

The `IaC Policy` workflow discovers modules containing
`tests/*.tftest.hcl`. For every discovered module it runs:

1. `tofu init -backend=false`;
1. `tofu validate`;
1. TFLint;
1. `tofu test`.

The suite runs against both the minimum supported OpenTofu version and the
latest stable version.

Repository quality gates additionally require:

- every Terraform module to have module-specific native test files;
- exactly one source-inventory contract per module;
- exactly one interface contract per module;
- each contract to use the suffix matching its test type.

The shared helpers under `tests/tofu` are not standalone test suites. Run
`tofu test` from a module that consumes them.

### Terraform test boundaries

These tests provide fast, offline feedback about Terraform source contracts,
public module interfaces, planned behavior, and validation. They do not prove:

- that AWS accepts the resulting API calls;
- that IAM permissions work in a deployed account;
- that external services interact correctly;
- that deployed infrastructure matches the repository;
- that an upgrade is safe for existing state.

Do not weaken an assertion merely to make a refactor pass. Decide whether the
contract is still required. If it is, update the implementation. If the
contract intentionally changed, update the relevant test and describe the
interface or behavior change in the pull request.

For the native test language and command options, see the
[OpenTofu test command documentation](https://opentofu.org/docs/cli/commands/test/).

## Mutation tests

`tests/mutation` protects small, high-risk security boundaries. A mutation test
changes production source in a controlled way—for example, weakening webhook
signature verification—and proves the associated tests detect the weakened
behavior.

Use mutation testing when ordinary line coverage is insufficient to establish
that a security check is meaningful. It is appropriate for trust boundaries,
secret handling, tenant isolation, payload verification, and critical failure
propagation. It is not the default for routine business logic because it adds
maintenance and execution cost.

Mutation cases must be deterministic. Do not use live network calls, real AWS,
wall-clock timing, or unseeded randomness.

Run the suite with:

```bash
cd tests
uv run --project .. --locked --only-group lambda-tests pytest -q mutation
```

When a mutation test fails, first determine whether the production boundary is
no longer protected or whether its associated unit test no longer observes the
important behavior. Do not make the mutation harmless merely to restore a
passing result.

## Quality gate tests

`tests/quality` contains meta-tests for the repository automation itself. These
tests verify, among other requirements, that:

- Terraform modules retain their required native tests;
- test filename conventions remain consistent;
- security, secret, and software-composition checks stay connected;
- locked dependencies and container quality controls remain in place;
- mutation suites remain connected to CI.

Run them with:

```bash
cd tests
uv run --project .. --locked --only-group lambda-tests pytest -q quality
```

Add or update a quality test when a repository-wide rule must not silently
disappear. If an existing quality test fails, fix the missing automation or
update an intentionally changed contract; do not delete the assertion only to
make the gate pass.

## MiniStack smoke tests

`tests/smoke` checks shallow AWS-like plumbing against MiniStack at
`http://localhost:4566`. It sits between isolated unit tests and a deployed
environment:

- `smoke` tests check S3, SQS and DLQ, SSM SecureString, EventBridge,
  CloudWatch Logs, STS identity, and IAM role create/assume mechanics;
- `lambda_exec` tests package and execute selected real Lambda handlers in
  MiniStack.

Use MiniStack when the risk is service wiring, emulator compatibility, Lambda
packaging, or real handler execution. Do not use it for logic that can be proven
more directly with a Lambda unit test.

Start MiniStack and run the suites from `tests/smoke`:

```bash
cd tests/smoke
make up
make smoke
make lambda
make down
```

`make lambda` requires Docker because MiniStack starts Lambda containers.
`make down` stops MiniStack and removes its local emulator state.

The tests use dummy credentials and point AWS clients at the local endpoint. A
local run skips if MiniStack is unavailable unless
`FORGE_REQUIRE_MINISTACK=1` is set. CI sets this variable so an unavailable
emulator fails rather than skips.

MiniStack smoke tests prove liveness and wiring, not production correctness.
They do not prove real IAM enforcement, tenant isolation, EKS or ARC behavior,
runner orchestration, or end-to-end Forge operation.

## Shared test support

`tests/support` contains shared pytest helpers for loading real handler modules,
building API Gateway events, and signing webhook payloads. It is imported by
test suites and is not run directly.

Keep assertions in the consuming test file so failures identify the behavior
under test. Support helpers should prepare realistic inputs and isolate
repetitive setup without hiding the expected result.

## Running the non-smoke suites

The root pytest configuration covers Lambda, offline IaC, quality, and mutation
tests. It deliberately excludes `tests/smoke` because that suite has its own
MiniStack and Docker lifecycle.

Run all non-smoke pytest suites:

```bash
cd tests
uv run --project .. --locked --only-group lambda-tests pytest -q
```

For normal development, start with the focused file or suite closest to the
change, then expand to the relevant surrounding suites before submitting the
pull request.

## CI lanes

CI keeps the different execution models separate:

| CI lane             | Suites                                               |
| ------------------- | ---------------------------------------------------- |
| `Lambda Unit Tests` | `tests/lambdas`                                      |
| `IaC Policy`        | `tests/iac` and module-local native OpenTofu tests   |
| `Quality Gates`     | `tests/quality` and `tests/mutation`                 |
| `MiniStack Smoke`   | `tests/smoke` with `smoke` and `lambda_exec` markers |

This separation makes failures easier to route. A unit-test failure belongs to
handler behavior, an IaC contract failure belongs to configuration wiring, a
quality failure belongs to repository automation, and a MiniStack failure
belongs first to local AWS-like plumbing or Lambda execution.
