# IaC Promotion And PR Plans

Use this for a repo like `forge-tenants-iac-aws` or `forge-infra-iac-aws`:
pull requests run plans, merges to `main` run applies, and all Terragrunt units
are discovered from the folder tree.

Change these values before copying:

| Value                     | Where                                                      |
| ------------------------- | ---------------------------------------------------------- |
| `k8s`                     | Runner label                                               |
| `dev`, `prod`             | GitHub environment names and Terraform environment folders |
| `eu-west-1`               | Default region                                             |
| `000000000000`            | AWS account IDs                                            |
| `forge-dev`, `forge-prod` | AWS profile names                                          |
| `owner`                   | Role name                                                  |

Create `.github/workflows/regression-tests.yml`:

```yaml
---
# yamllint disable rule:comments
# yamllint disable rule:truthy
name: Regression tests

on:
  pull_request:
    types:
      - opened
      - synchronize
      - reopened
    branches:
      - main
    paths:
      - .github/actions/**
      - .github/workflows/**
      - release_versions.y*ml
      - terraform/**

permissions: {}

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

jobs:
  terragrunt-plan:
    name: Terragrunt plan - ${{ matrix.env }}
    permissions:
      contents: read
      pull-requests: write
    strategy:
      fail-fast: false
      matrix:
        include:
          - env: dev
            aws-region: eu-west-1
            aws-account-id: '000000000000'
            aws-profile: forge-dev
            tf-target-env: dev
          - env: prod
            aws-region: eu-west-1
            aws-account-id: '000000000000'
            aws-profile: forge-prod
            tf-target-env: prod
    uses: ./.github/workflows/rw-terragrunt.yml
    with:
      aws-region: ${{ matrix.aws-region }}
      aws-account-id: ${{ matrix.aws-account-id }}
      aws-profile: ${{ matrix.aws-profile }}
      role-name: owner
      tf-target-env: ${{ matrix.tf-target-env }}
      env: ${{ matrix.env }}
      run-apply: 'false'
```

Create `.github/workflows/promotion.yml`:

```yaml
---
# yamllint disable rule:comments
# yamllint disable rule:truthy
name: Promotion

on:
  push:
    branches:
      - main
    paths:
      - .github/actions/**
      - .github/workflows/**
      - release_versions.y*ml
      - terraform/**
  workflow_dispatch:

permissions: {}

concurrency:
  group: forge-terraform-promotion
  cancel-in-progress: false

jobs:
  terragrunt-apply:
    name: Terragrunt apply - ${{ matrix.env }}
    permissions:
      contents: read
      pull-requests: write
    strategy:
      fail-fast: false
      matrix:
        include:
          - env: dev
            aws-region: eu-west-1
            aws-account-id: '000000000000'
            aws-profile: forge-dev
            tf-target-env: dev
          - env: prod
            aws-region: eu-west-1
            aws-account-id: '000000000000'
            aws-profile: forge-prod
            tf-target-env: prod
    uses: ./.github/workflows/rw-terragrunt.yml
    with:
      aws-region: ${{ matrix.aws-region }}
      aws-account-id: ${{ matrix.aws-account-id }}
      aws-profile: ${{ matrix.aws-profile }}
      role-name: owner
      tf-target-env: ${{ matrix.tf-target-env }}
      env: ${{ matrix.env }}
      run-apply: 'true'
```

Create `.github/workflows/rw-terragrunt.yml`:

```yaml
---
# yamllint disable rule:comments
# yamllint disable rule:truthy
name: Reusable Terragrunt Workflow

on:
  workflow_call:
    inputs:
      aws-region:
        type: string
        required: true
      aws-account-id:
        type: string
        required: true
      aws-profile:
        type: string
        required: true
      role-name:
        type: string
        required: true
      tf-target-env:
        type: string
        required: true
      run-apply:
        type: string
        required: false
        default: 'false'
      env:
        type: string
        required: true

permissions: {}

jobs:
  discover:
    name: Discover Terragrunt units
    runs-on: k8s
    permissions:
      contents: read
    environment: ${{ inputs.run-apply == 'true' && inputs.env || '' }}
    outputs:
      units: ${{ steps.set-matrix.outputs.units }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # v7.0.0
        with:
          persist-credentials: false

      - id: set-matrix
        name: Build Terragrunt matrix
        shell: bash
        env:
          TF_TARGET_ENV: ${{ inputs.tf-target-env }}
        run: |
          set -euo pipefail

          tf_path="terraform/environments/${TF_TARGET_ENV}"
          if [[ ! -d "$tf_path" ]]; then
            echo "Missing Terragrunt environment path: $tf_path" >&2
            exit 1
          fi

          units_json=$(
            find "$tf_path" -name terragrunt.hcl -not -path '*/.terragrunt-cache/*' |
              sed 's#/terragrunt.hcl$##' |
              sort |
              jq -R -s -c 'split("\n") | map(select(length > 0)) | map({path: .})'
          )

          echo "$units_json" | jq .
          echo "units=$units_json" >> "$GITHUB_OUTPUT"

  terragrunt:
    name: Terragrunt - ${{ matrix.unit.path }}
    needs:
      - discover
    runs-on: k8s
    permissions:
      contents: read
      pull-requests: write
    environment: ${{ inputs.run-apply == 'true' && inputs.env || '' }}
    strategy:
      fail-fast: false
      max-parallel: 1
      matrix:
        unit: ${{ fromJSON(needs.discover.outputs.units) }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # v7.0.0
        with:
          persist-credentials: false

      - name: Run Terragrunt
        uses: ./.github/actions/terragrunt-deployment-action
        with:
          aws-region: ${{ inputs.aws-region }}
          aws-account-id: ${{ inputs.aws-account-id }}
          aws-profile: ${{ inputs.aws-profile }}
          role-name: ${{ inputs.role-name }}
          tf-target-env: ${{ inputs.tf-target-env }}
          tf-path: ${{ matrix.unit.path }}
          run-apply: ${{ inputs.run-apply }}
```

## Expected Repo Layout

```text
terraform/
└── environments/
    ├── dev/
    │   └── regions/
    │       └── eu-west-1/
    └── prod/
        └── regions/
            └── eu-west-1/
```

Every folder containing `terragrunt.hcl` becomes one matrix item. Keep
`max-parallel: 1` until the repo has explicit dependency-safe grouping.
