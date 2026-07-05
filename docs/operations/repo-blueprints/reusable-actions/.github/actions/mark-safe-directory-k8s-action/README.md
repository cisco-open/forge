# Mark Safe Directory Action (K8s / ARC)

This GitHub Action ensures that the Git repository is marked as safe and fixes common ephemeral runner issues in Kubernetes/ARC environments.

## Example Usage

```yaml
name: Pre-commit Check

on:
  pull_request:
    paths:
      - '**/*.py'
      - '.pre-commit-config.yaml'

jobs:
  pre-commit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2

      - name: Mark Git repo safe for K8s ARC
        uses: ./.github/actions/mark-safe-directory-k8s-action

      - name: Run pre-commit
        run: pre-commit run --all-files
```
