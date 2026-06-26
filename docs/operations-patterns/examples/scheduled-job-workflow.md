# Example: Scheduled Maintenance Job

Use this for cron-style Forge operations such as stale PR labeling, report
publication, drift inventory, or periodic smoke tests.

```yaml
name: Scheduled Maintenance

on:
  schedule:
    - cron: "17 6 * * 1-5"
  workflow_dispatch:
    inputs:
      dry_run:
        type: boolean
        default: true
      target:
        type: string
        default: "all"

permissions:
  contents: read
  pull-requests: write
  issues: write

concurrency:
  group: scheduled-maintenance
  cancel-in-progress: false

jobs:
  run:
    runs-on: <runner-label>
    steps:
      - uses: actions/checkout@<pinned-version>
      - uses: ./.github/actions/<auth-adapter>
      - name: Run maintenance task
        shell: bash
        env:
          DRY_RUN: ${{ inputs.dry_run || 'true' }}
          TARGET: ${{ inputs.target || 'all' }}
        run: |
          ./scripts/maintenance-task.sh \
            --target "$TARGET" \
            --dry-run "$DRY_RUN" \
            --summary-file maintenance-summary.md
      - name: Publish summary
        shell: bash
        run: |
          cat maintenance-summary.md >> "$GITHUB_STEP_SUMMARY"
```

## Required Summary Fields

```markdown
# Scheduled Maintenance Summary

- Mode:
- Target:
- Started:
- Completed:
- Changed:
- Skipped:
- Failed:

## Failed Targets

| Target | Reason | Next Step |
| --- | --- | --- |
```

## Replace Before Use

- cron schedule
- permissions
- `<auth-adapter>`
- `./scripts/maintenance-task.sh`
- summary fields
