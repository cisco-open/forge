# Scheduled Maintenance

Use these workflow shapes for cron-style operational work. Keep the operation
in a script or policy file; the workflow should own schedule, credentials,
locking, and artifact upload.

## Cloud Custodian Sweep

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
  group: cloud-custodian
  cancel-in-progress: false

jobs:
  run-custodian:
    name: Run Cloud Custodian
    runs-on: k8s
    steps:
      - name: Checkout repository
        uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # v7.0.0
        with:
          persist-credentials: false

      - name: Acquire lock
        uses: example-org/forge-reusable-actions/.github/actions/global-lock-action@<reusable-actions-ref>
        with:
          lock-action: acquire
          lock-id: forge-cloud-custodian

      - name: Configure AWS credentials
        uses: example-org/forge-reusable-actions/.github/actions/aws-action@<reusable-actions-ref>
        with:
          role-skip-session-tagging: 'true'

      - name: Run Cloud Custodian
        shell: bash
        run: custodian run -s output --region eu-west-1 policies/*.yml

      - name: Upload output
        if: always()
        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7
        with:
          name: cloud-custodian-output
          path: output
          if-no-files-found: ignore

      - name: Release lock
        if: always()
        uses: example-org/forge-reusable-actions/.github/actions/global-lock-action@<reusable-actions-ref>
        with:
          lock-action: release
          lock-id: forge-cloud-custodian
```

## Scripted Maintenance Job

Create `.github/workflows/retag-state-backends.yml`:

```yaml
---
# yamllint disable rule:comments
# yamllint disable rule:truthy
name: Retag state backends

on:
  workflow_dispatch:
  schedule:
    - cron: 0 6 * * 1

permissions:
  contents: read
  pull-requests: write

concurrency:
  group: retag-state-backends
  cancel-in-progress: false

jobs:
  run:
    name: Retag state backends
    runs-on: k8s
    steps:
      - name: Checkout repository
        uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # v7.0.0
        with:
          persist-credentials: false

      - name: Configure AWS credentials
        uses: example-org/forge-reusable-actions/.github/actions/aws-action@<reusable-actions-ref>
        with:
          role-skip-session-tagging: 'true'

      - name: Run retag script
        shell: bash
        run: ./scripts/retag_state_backends.sh
```

## Workflow Rules

- Use `workflow_dispatch` on every scheduled job so operators can rerun it.
- Use a lock for jobs that mutate shared accounts, tags, or repositories.
- Use `cancel-in-progress: false` for jobs that mutate remote systems.
- Upload output when the job changes remote state or produces an audit trail.
- Keep destructive logic in scripts with shell checks, not inline workflow YAML.
