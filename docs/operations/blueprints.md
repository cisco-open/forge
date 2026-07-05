# Copyable Blueprints

These are starting files. Copy the block, replace the placeholders, then run the
checks from [Required Checks](required-checks.md).

For complete file sets, use [Real Workflow Files](workflows/index.md). This
page stays short on purpose.

## Baseline PR Gate

Create `.github/workflows/pre-commit.yml`:

```yaml
---
# yamllint disable rule:comments
# yamllint disable rule:truthy
name: Pre-commit Code Quality Checks

on:
  pull_request:
    types:
      - opened
      - synchronize
      - reopened
    branches:
      - main
  push:
    branches:
      - main

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

jobs:
  run-pre-commit:
    name: Run pre-commit
    runs-on: <runner-labels>
    steps:
      - name: Checkout repository
        uses: actions/checkout@<checkout-ref>
        with:
          persist-credentials: false

      - name: Run pre-commit
        shell: bash
        run: pre-commit run --show-diff-on-failure --color=always --all-files
```

Replace:

- `<runner-labels>` with `ubuntu-latest`, `k8s`, or your self-hosted label list.
- `<checkout-ref>` with the pinned checkout SHA used by your org.

## IaC Promotion Workflow

Create `.github/workflows/promotion.yml`:

```yaml
---
# yamllint disable rule:comments
# yamllint disable rule:truthy
name: Terraform Environment Promotion

on:
  push:
    branches:
      - main
    paths:
      - <release-version-file>
      - terraform/**
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: <repo>_terraform
  cancel-in-progress: false

jobs:
  terraform-deployment:
    name: Terragrunt Deployment ${{ matrix.env }}
    permissions:
      contents: read
      pull-requests: write
    strategy:
      fail-fast: false
      matrix:
        include:
          - env: <environment-name-dev>
            aws-region: <aws-region>
            aws-account-id: '<dev-aws-account-id>'
            aws-profile: <dev-aws-profile>
            tf-target-env: dev
          - env: <environment-name-prod>
            aws-region: <aws-region>
            aws-account-id: '<prod-aws-account-id>'
            aws-profile: <prod-aws-profile>
            tf-target-env: prod

    uses: ./.github/workflows/rw-terragrunt.yml
    with:
      aws-region: ${{ matrix.aws-region }}
      aws-account-id: ${{ matrix.aws-account-id }}
      aws-profile: ${{ matrix.aws-profile }}
      role-name: <role-name>
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
    runs-on: <runner-labels>
    permissions:
      contents: read
    environment: ${{ inputs.run-apply == 'true' && inputs.env || '' }}
    outputs:
      units: ${{ steps.set-matrix.outputs.units }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@<checkout-ref>
        with:
          persist-credentials: false

      - id: set-matrix
        shell: bash
        env:
          TF_TARGET_ENV: ${{ inputs.tf-target-env }}
        run: |
          set -euo pipefail
          tf_path="terraform/environments/${TF_TARGET_ENV}"
          units_json=$(
            find "$tf_path" -name terragrunt.hcl -not -path '*/.terragrunt-cache/*' |
              sed 's#/terragrunt.hcl$##' |
              jq -R -s -c 'split("\n") | map(select(length > 0)) | map({path: .})'
          )
          echo "$units_json" | jq .
          echo "units=$units_json" >> "$GITHUB_OUTPUT"

  terragrunt:
    name: Terragrunt - ${{ matrix.unit.path }}
    needs:
      - discover
    runs-on: <runner-labels>
    permissions:
      contents: read
      pull-requests: write
    environment: ${{ inputs.run-apply == 'true' && inputs.env || '' }}
    strategy:
      fail-fast: false
      matrix:
        unit: ${{ fromJSON(needs.discover.outputs.units) }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@<checkout-ref>
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

You still need a local `.github/actions/terragrunt-deployment-action/action.yml`
that handles credentials, `terragrunt plan`, `terragrunt apply`, comments, and
lock behavior for your environment.

## Weekly Forge Example Test

Create `.github/workflows/rw-example-folder.yml`:

```yaml
---
name: Reusable Forge Example Folder

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
    name: Discover ${{ inputs.example-folder }} modules
    runs-on: <runner-labels>
    outputs:
      modules: ${{ steps.discover.outputs.terragrunt-modules }}
    steps:
      - uses: actions/checkout@<checkout-ref>
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
    runs-on: <runner-labels>
    strategy:
      fail-fast: true
      max-parallel: 1
      matrix:
        module: ${{ fromJSON(needs.discover.outputs.modules) }}
    steps:
      - uses: actions/checkout@<checkout-ref>
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

Create `.github/workflows/test-examples.yml`:

```yaml
---
# yamllint disable rule:truthy
name: Test examples deployment

on:
  workflow_dispatch:
  schedule:
    - cron: 0 4 * * 1

permissions:
  contents: read

concurrency:
  group: <repo>
  cancel-in-progress: false

jobs:
  apply-helpers:
    uses: ./.github/workflows/rw-example-folder.yml
    with:
      example-folder: helpers
      operation: apply
      terragrunt-command: apply
      ref: ${{ github.head_ref || github.ref_name || 'main' }}

  apply-infra:
    needs: apply-helpers
    uses: ./.github/workflows/rw-example-folder.yml
    with:
      example-folder: infra
      operation: apply
      terragrunt-command: apply
      ref: ${{ github.head_ref || github.ref_name || 'main' }}

  apply-platform:
    needs: apply-infra
    uses: ./.github/workflows/rw-example-folder.yml
    with:
      example-folder: platform
      operation: apply
      terragrunt-command: apply
      ref: ${{ github.head_ref || github.ref_name || 'main' }}

  apply-integrations:
    needs: apply-platform
    uses: ./.github/workflows/rw-example-folder.yml
    with:
      example-folder: integrations
      operation: apply
      terragrunt-command: apply
      ref: ${{ github.head_ref || github.ref_name || 'main' }}

  destroy-integrations:
    needs: apply-integrations
    uses: ./.github/workflows/rw-example-folder.yml
    with:
      example-folder: integrations
      operation: destroy
      terragrunt-command: destroy
      ref: ${{ github.head_ref || github.ref_name || 'main' }}

  destroy-platform:
    needs: destroy-integrations
    uses: ./.github/workflows/rw-example-folder.yml
    with:
      example-folder: platform
      operation: destroy
      terragrunt-command: destroy
      ref: ${{ github.head_ref || github.ref_name || 'main' }}

  destroy-infra:
    needs: destroy-platform
    uses: ./.github/workflows/rw-example-folder.yml
    with:
      example-folder: infra
      operation: destroy
      terragrunt-command: destroy
      ref: ${{ github.head_ref || github.ref_name || 'main' }}

  destroy-helpers:
    needs: destroy-infra
    uses: ./.github/workflows/rw-example-folder.yml
    with:
      example-folder: helpers
      operation: destroy
      terragrunt-command: destroy
      ref: ${{ github.head_ref || github.ref_name || 'main' }}
```

This is the core Forge adoption test. A company can remove or empty
`integrations` if it does not use optional integrations.

## Scheduled Cloud Custodian Job

Create `.github/workflows/cloud-custodian.yml`:

```yaml
---
# yamllint disable rule:comments
# yamllint disable rule:truthy
name: Cloud Custodian

on:
  workflow_dispatch:
  schedule:
    - cron: 0 3 * * *

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: false

jobs:
  run-custodian:
    name: Run Cloud Custodian
    runs-on: <runner-labels>
    steps:
      - uses: actions/checkout@<checkout-ref>
        with:
          persist-credentials: false

      - name: Acquire lock
        uses: <org>/<reusable-actions-repo>/.github/actions/global-lock-action@<reusable-actions-ref>
        with:
          lock-action: acquire
          lock-id: <repo>-cloud-custodian

      - name: Configure AWS credentials
        uses: <org>/<reusable-actions-repo>/.github/actions/aws-action@<reusable-actions-ref>
        with:
          role-skip-session-tagging: true

      - name: Run Cloud Custodian
        shell: bash
        run: custodian run -s output/ --region <aws-region> policies/*.yml

      - name: Release lock
        if: always()
        uses: <org>/<reusable-actions-repo>/.github/actions/global-lock-action@<reusable-actions-ref>
        with:
          lock-action: release
          lock-id: <repo>-cloud-custodian
```

## Scheduled Script Job

Create `.github/workflows/<job-name>.yml`:

```yaml
---
name: <job-name>

on:
  workflow_dispatch:
  schedule:
    - cron: '*/15 * * * *'

permissions:
  contents: read
  pull-requests: write

concurrency:
  group: <repo>-<job-name>
  cancel-in-progress: false

jobs:
  run:
    name: <job-name>
    runs-on: <runner-labels>
    steps:
      - uses: actions/checkout@<checkout-ref>
        with:
          persist-credentials: false

      - name: Get automation token
        id: app-token
        uses: actions/create-github-app-token@<create-github-app-token-ref>
        with:
          app-id: ${{ secrets.<APP_ID_SECRET> }}
          private-key: ${{ secrets.<APP_PRIVATE_KEY_SECRET> }}
          owner: <org>
          permission-issues: write
          permission-pull-requests: write

      - name: Run job
        shell: bash
        env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
        run: ./scripts/<job-name>/<job-name>.sh
```

## Renovate Job

Create `.github/workflows/renovate.yml`:

```yaml
---
name: RenovateBot

on:
  schedule:
    - cron: 0 */4 * * *
  workflow_dispatch:

permissions: {}

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: false

jobs:
  renovate:
    name: Run Renovate
    runs-on: <runner-labels>
    permissions:
      contents: read
      actions: write
    steps:
      - uses: actions/checkout@<checkout-ref>
        with:
          persist-credentials: false

      - name: Configure credentials
        uses: <org>/<reusable-actions-repo>/.github/actions/aws-action@<reusable-actions-ref>

      - name: Prepare Renovate log directory
        shell: bash
        run: install -d -m 755 "${RUNNER_TEMP}/renovate-logs"

      - name: Self-hosted Renovate
        uses: renovatebot/github-action@<renovate-action-ref>
        with:
          configurationFile: default.json
          token: ${{ secrets.<RENOVATE_TOKEN_SECRET> }}
        env:
          LOG_LEVEL: warn
          LOG_FILE: /tmp/renovate-logs/renovate.log
          LOG_FILE_FORMAT: json
          LOG_FILE_LEVEL: debug
          RENOVATE_ONBOARDING: 'false'

      - name: Upload Renovate logs
        if: always()
        uses: actions/upload-artifact@<upload-artifact-ref>
        with:
          name: renovate-logs
          path: ${{ runner.temp }}/renovate-logs/
          if-no-files-found: warn
          retention-days: 14
```

Add private registry, AWS AMI lookup, and enterprise GitHub authentication only
when the target repos need them.
