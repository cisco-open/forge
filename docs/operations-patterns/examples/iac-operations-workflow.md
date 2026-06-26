# Example: IaC Operations Workflow

Use this shape for a repository that stores declared operational state. Pull
requests run dry-run validation. Protected branch or manual dispatch runs apply
behind an approval gate.

```yaml
name: IaC Operations

on:
  pull_request:
    paths:
      - "environments/**"
      - "modules/**"
      - ".github/workflows/iac-operations.yml"
  push:
    branches: [main]
    paths:
      - "environments/**"
      - "modules/**"
  workflow_dispatch:
    inputs:
      target_environment:
        type: choice
        options: [dev, stage, prod]
        default: dev
      run_apply:
        type: boolean
        default: false

permissions:
  contents: read
  pull-requests: write

concurrency:
  group: iac-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: false

jobs:
  discover:
    runs-on: <runner-label>
    outputs:
      units: ${{ steps.discover.outputs.units }}
      has_units: ${{ steps.discover.outputs.has_units }}
    steps:
      - uses: actions/checkout@<pinned-version>
      - id: discover
        shell: bash
        run: |
          # Replace with repo-specific unit discovery.
          find environments -name unit.yaml -print \
            | jq -R '{"path": ., "name": (. | split("/")[-2]), "layer": 0}' \
            | jq -s -c . > units.json
          echo "units=$(cat units.json)" >> "$GITHUB_OUTPUT"
          echo "has_units=$(jq 'length > 0' units.json)" >> "$GITHUB_OUTPUT"

  dry-run:
    needs: discover
    if: needs.discover.outputs.has_units == 'true'
    runs-on: <runner-label>
    strategy:
      fail-fast: false
      matrix:
        unit: ${{ fromJSON(needs.discover.outputs.units) }}
    steps:
      - uses: actions/checkout@<pinned-version>
      - uses: ./.github/actions/<auth-adapter>
      - uses: ./.github/actions/<deployment-adapter>
        with:
          command: dry-run
          path: ${{ matrix.unit.path }}

  apply:
    needs: [discover, dry-run]
    if: github.event_name == 'push' || (github.event_name == 'workflow_dispatch' && inputs.run_apply == true)
    runs-on: <runner-label>
    environment: iac-apply-${{ inputs.target_environment || 'prod' }}
    strategy:
      fail-fast: false
      matrix:
        unit: ${{ fromJSON(needs.discover.outputs.units) }}
    steps:
      - uses: actions/checkout@<pinned-version>
      - uses: ./.github/actions/<auth-adapter>
      - uses: ./.github/actions/<deployment-adapter>
        with:
          command: apply
          path: ${{ matrix.unit.path }}

  validate:
    needs: [discover, dry-run, apply]
    if: always()
    runs-on: <runner-label>
    steps:
      - shell: bash
        run: |
          test "${{ needs.discover.result }}" = "success"
          if [ "${{ needs.discover.outputs.has_units }}" = "true" ]; then
            test "${{ needs.dry-run.result }}" = "success"
          fi
          if [ "${{ needs.apply.result }}" != "skipped" ]; then
            test "${{ needs.apply.result }}" = "success"
          fi
```

## Replace Before Use

- unit discovery logic
- `<auth-adapter>`
- `<deployment-adapter>`
- environment names
- branch protection check name
