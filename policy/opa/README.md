# ForgeMT policy-as-code (OPA / conftest)

These Rego policies encode tenant-isolation invariants as CI gates (see
`docs-improvement/phase1-audit-register.md`, findings P0-7 and P1-8). They
complement — they do not replace — the `tofu fmt`/`validate`/`tflint` hooks that
already run in pre-commit. The genuine Phase 1 gap was **policy-as-code**, not
formatting/validation (register P1-10).

## What they enforce

`forge_iac.rego` evaluates an IAM or S3 policy **JSON document** (input is a
single policy with a `Statement` list) and denies:

1. **Wildcard `sts:AssumeRole` principal** — a tenant/forge trust policy must
   name an explicit principal; a `"*"` principal breaks the STS isolation
   boundary.
1. **Unscoped tenant bucket policy** — an S3 statement granting a wildcard
   principal with no `Condition` (cross-tenant read/write risk).

## Running

Validate the policy logic itself (deterministic, no AWS, no tofu plan — this is
the CI hard gate):

```sh
conftest verify --policy policy/opa
```

Gate a rendered policy document:

```sh
conftest test some-policy.json --policy policy/opa
```

## Extending to the live plan (follow-up)

To gate the real modules end-to-end, render a plan and convert to JSON, then
feed the IAM/bucket policy documents to `conftest test`. That path needs
`tofu init`/`plan` and is intentionally **not** wired into the fast per-PR job;
it belongs in the slower integration job (see `iac-policy.yml` notes). Until
then, `checkov` (soft-fail + SARIF) provides broad coverage over the HCL.
