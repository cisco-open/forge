# OpenTofu Test Helpers

## What This Is

`tests/tofu` contains shared helper modules for native OpenTofu tests. It is not
a standalone test suite.

## Why It Is Used

Module-local `.tftest.hcl` files reuse these helpers to keep common contract
assertions consistent without copying the same HCL into every module.

## CI Execution

The `IaC Policy` workflow discovers module-local test files with:

```bash
find modules -path '*/tests/*.tftest.hcl'
```

For each discovered module, CI runs `tofu init -backend=false`, `tofu validate`,
`tflint`, and `tofu test` against the minimum supported and latest stable
OpenTofu versions. CI does not run `tofu test` from this helper directory.

## Local Execution

Run from a consuming module, for example:

```bash
tofu -chdir=modules/platform/arc init -backend=false -input=false
tofu -chdir=modules/platform/arc test -no-color
```
