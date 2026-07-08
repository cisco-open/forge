# OPA Tenant-Isolation Policies

## What This Is

`policy/opa` contains Rego policies for conftest. The current policy file,
`forge_iac.rego`, evaluates IAM or S3 policy JSON documents where the input is a
single policy document with a `Statement` list.

## Why It Is Used

These policies encode tenant-isolation invariants as CI gates. They complement
OpenTofu formatting, validation, TFLint, and Checkov by pinning Forge-specific
security expectations:

1. Wildcard principals must not be able to call `sts:AssumeRole`.
1. Tenant bucket policies must not grant S3 access to wildcard principals without
   a scoping `Condition`.

The embedded `test_*` Rego rules make the policy logic deterministic and
hermetic: no AWS, no backend, no Terraform plan, and no network are required.

## CI Execution

The `IaC Policy` workflow installs conftest and runs this as a hard gate:

```sh
conftest verify --policy policy/opa
```

That command validates the policy's self-tests. It does not currently render
module plans or evaluate live cloud state.

## Local Execution

Run the same hard gate locally with:

```sh
conftest verify --policy policy/opa
```

To check a rendered policy document manually:

```sh
conftest test some-policy.json --policy policy/opa
```

## What This Does Not Prove

- It does not contact AWS or prove behavior in a deployed account.
- It does not render every Terraform plan in CI today.
- It does not replace module-local OpenTofu tests or Python Lambda tests.

To gate rendered modules end to end, add a slower integration job that runs
`tofu init`, creates a JSON plan, extracts IAM and S3 policy documents, and feeds
those documents to `conftest test`.
