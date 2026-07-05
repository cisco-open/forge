# Weekly Example Deployments

Use this for a repo like `forge-examples-iac-aws`. It checks out Forge,
discovers generated Terragrunt units, applies the examples weekly, and destroys
them in reverse category order.

This workflow uses the examples-repo variant of
`.github/actions/terragrunt-deployment-action/action.yml`. That action must
support these inputs:

| Input                  | Purpose                                               |
| ---------------------- | ----------------------------------------------------- |
| `example-folder`       | One of `helpers`, `infra`, `integrations`, `platform` |
| `run-type`             | `discover`, `apply`, or `destroy`                     |
| `terragrunt-command`   | `apply` or `destroy` queue construction               |
| `terragrunt-unit-path` | One discovered unit path                              |
| `ref`                  | Forge branch, tag, or commit to test                  |

Create `.github/workflows/test-examples.yml`:

```yaml
---
# yamllint disable rule:comments
# yamllint disable rule:truthy
name: Test examples deployment

on:
  pull_request:
    branches:
      - main
    paths:
      - .github/actions/**
      - .github/workflows/test-examples.yml
  workflow_dispatch:
    inputs:
      ref:
        description: Forge ref to test
        required: false
        default: main
  schedule:
    - cron: 0 4 * * 1

permissions:
  contents: read

concurrency:
  group: forge-examples-weekly
  cancel-in-progress: false

jobs:
  apply-helpers:
    uses: ./.github/workflows/rw-example-category.yml
    with:
      example-folder: helpers
      operation: apply
      terragrunt-command: apply
      ref: ${{ inputs.ref || github.head_ref || github.ref_name || 'main' }}

  apply-infra:
    needs:
      - apply-helpers
    uses: ./.github/workflows/rw-example-category.yml
    with:
      example-folder: infra
      operation: apply
      terragrunt-command: apply
      ref: ${{ inputs.ref || github.head_ref || github.ref_name || 'main' }}

  apply-platform:
    needs:
      - apply-infra
    uses: ./.github/workflows/rw-example-category.yml
    with:
      example-folder: platform
      operation: apply
      terragrunt-command: apply
      ref: ${{ inputs.ref || github.head_ref || github.ref_name || 'main' }}

  apply-integrations:
    needs:
      - apply-platform
    uses: ./.github/workflows/rw-example-category.yml
    with:
      example-folder: integrations
      operation: apply
      terragrunt-command: apply
      ref: ${{ inputs.ref || github.head_ref || github.ref_name || 'main' }}

  destroy-integrations:
    needs:
      - apply-integrations
    uses: ./.github/workflows/rw-example-category.yml
    with:
      example-folder: integrations
      operation: destroy
      terragrunt-command: destroy
      ref: ${{ inputs.ref || github.head_ref || github.ref_name || 'main' }}

  destroy-platform:
    needs:
      - destroy-integrations
    uses: ./.github/workflows/rw-example-category.yml
    with:
      example-folder: platform
      operation: destroy
      terragrunt-command: destroy
      ref: ${{ inputs.ref || github.head_ref || github.ref_name || 'main' }}

  destroy-infra:
    needs:
      - destroy-platform
    uses: ./.github/workflows/rw-example-category.yml
    with:
      example-folder: infra
      operation: destroy
      terragrunt-command: destroy
      ref: ${{ inputs.ref || github.head_ref || github.ref_name || 'main' }}

  destroy-helpers:
    needs:
      - destroy-infra
    uses: ./.github/workflows/rw-example-category.yml
    with:
      example-folder: helpers
      operation: destroy
      terragrunt-command: destroy
      ref: ${{ inputs.ref || github.head_ref || github.ref_name || 'main' }}
```

Create `.github/workflows/rw-example-category.yml`:

```yaml
---
# yamllint disable rule:comments
# yamllint disable rule:truthy
name: Reusable Forge example category

on:
  workflow_call:
    inputs:
      example-folder:
        type: string
        required: true
      operation:
        type: string
        required: true
      terragrunt-command:
        type: string
        required: true
      ref:
        type: string
        required: false
        default: main

permissions:
  contents: read

jobs:
  discover:
    name: Discover ${{ inputs.example-folder }} ${{ inputs.operation }} units
    runs-on: k8s
    outputs:
      modules: ${{ steps.discover.outputs.terragrunt-modules }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # v7.0.0
        with:
          persist-credentials: false

      - name: Discover Terragrunt modules
        id: discover
        uses: ./.github/actions/terragrunt-deployment-action
        with:
          example-folder: ${{ inputs.example-folder }}
          run-type: discover
          terragrunt-command: ${{ inputs.terragrunt-command }}
          create-lock: 'false'
          ref: ${{ inputs.ref }}

  run:
    name: ${{ inputs.operation }} ${{ inputs.example-folder }} - ${{ matrix.module.path }}
    needs:
      - discover
    runs-on: k8s
    strategy:
      fail-fast: true
      max-parallel: 1
      matrix:
        module: ${{ fromJSON(needs.discover.outputs.modules) }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # v7.0.0
        with:
          persist-credentials: false

      - name: Run Terragrunt
        uses: ./.github/actions/terragrunt-deployment-action
        with:
          example-folder: ${{ inputs.example-folder }}
          run-type: ${{ inputs.operation }}
          terragrunt-unit-path: ${{ matrix.module.path }}
          ref: ${{ inputs.ref }}
```

## Expected Forge Example Layout

```text
forge/
└── examples/
    └── deployments/
        ├── helpers/
        │   └── terragrunt/environments/prod/
        ├── infra/
        │   └── terragrunt/environments/prod/
        ├── integrations/
        │   └── terragrunt/environments/prod/
        └── platform/
            └── terragrunt/environments/prod/
```

If the company does not use Splunk, keep `integrations` but put only the
integration modules it actually supports. An empty integrations category is
better than a required Splunk deployment that the platform does not need.
