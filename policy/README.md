# Policy Gates

## What This Is

`policy` contains policy-as-code used by Forge CI. The current implementation is
under `policy/opa` and uses OPA/Rego with conftest.

## Why It Is Used

Forge is a multi-tenant runner platform, so infrastructure changes must preserve
tenant isolation. Policy-as-code gives the repo an explicit gate for invariants
that are easy to weaken in Terraform, especially trust-policy and bucket-policy
boundaries.

## CI Execution

The `IaC Policy` workflow runs the OPA gate when Terraform, module tests, policy
files, or the workflow change. The hard gate is:

```bash
conftest verify --policy policy/opa
```

The same workflow also runs Checkov over `modules/` as an informational SARIF
scan:

```bash
checkov --directory modules/ --framework terraform \
  --skip-path '.*/\.terraform/.*' \
  --skip-download \
  --soft-fail \
  --output cli --output sarif --output-file-path console,results.sarif
```

Checkov currently reports findings without blocking the PR; conftest policy
self-tests are the blocking policy gate.

## Local Execution

Install conftest and run:

```bash
conftest verify --policy policy/opa
```

To evaluate a rendered IAM or S3 policy JSON document:

```bash
conftest test path/to/policy.json --policy policy/opa
```

No AWS credentials, live environment, Terraform backend, or Docker are required
for the OPA verification path.
