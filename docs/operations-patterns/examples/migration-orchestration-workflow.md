# Example: Migration Orchestration Workflow

Use this when Forge needs a repeatable active/inactive migration with explicit
phases and checkpoints.

```yaml
name: Runtime Migration

on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [dev, stage, prod]
permissions:
  contents: read
  actions: write

concurrency:
  group: runtime-migration-${{ inputs.environment }}
  cancel-in-progress: false

jobs:
  discovery:
    runs-on: <runner-label>
    outputs:
      active_target: ${{ steps.discover.outputs.active_target }}
      inactive_target: ${{ steps.discover.outputs.inactive_target }}
      workloads: ${{ steps.discover.outputs.workloads }}
    steps:
      - uses: actions/checkout@<pinned-version>
      - id: discover
        shell: bash
        run: |
          ./scripts/discover-runtime-state.sh \
            --environment "${{ inputs.environment }}" \
            --output runtime-state.json
          echo "active_target=$(jq -r .active runtime-state.json)" >> "$GITHUB_OUTPUT"
          echo "inactive_target=$(jq -r .inactive runtime-state.json)" >> "$GITHUB_OUTPUT"
          echo "workloads=$(jq -c .workloads runtime-state.json)" >> "$GITHUB_OUTPUT"

  disable-workflows:
    needs: discovery
    runs-on: <runner-label>
    steps:
      - uses: actions/checkout@<pinned-version>
      - uses: ./.github/actions/<workflow-toggle-adapter>
        with:
          state: disabled
          reason: runtime-migration

  recreate-inactive:
    needs: [discovery, disable-workflows]
    runs-on: <runner-label>
    environment: migration-${{ inputs.environment }}
    steps:
      - uses: actions/checkout@<pinned-version>
      - uses: ./.github/actions/<deployment-adapter>
        with:
          command: recreate
          target: ${{ needs.discovery.outputs.inactive_target }}

  move-to-inactive:
    needs: [discovery, recreate-inactive]
    runs-on: <runner-label>
    strategy:
      fail-fast: false
      matrix:
        workload: ${{ fromJSON(needs.discovery.outputs.workloads) }}
    steps:
      - uses: actions/checkout@<pinned-version>
      - uses: ./.github/actions/<migration-adapter>
        with:
          workload: ${{ matrix.workload.name }}
          target: ${{ needs.discovery.outputs.inactive_target }}

  recreate-active:
    needs: [discovery, move-to-inactive]
    runs-on: <runner-label>
    environment: migration-${{ inputs.environment }}
    steps:
      - uses: actions/checkout@<pinned-version>
      - uses: ./.github/actions/<deployment-adapter>
        with:
          command: recreate
          target: ${{ needs.discovery.outputs.active_target }}

  move-to-active:
    needs: [discovery, recreate-active]
    runs-on: <runner-label>
    strategy:
      fail-fast: false
      matrix:
        workload: ${{ fromJSON(needs.discovery.outputs.workloads) }}
    steps:
      - uses: actions/checkout@<pinned-version>
      - uses: ./.github/actions/<migration-adapter>
        with:
          workload: ${{ matrix.workload.name }}
          target: ${{ needs.discovery.outputs.active_target }}

  enable-workflows:
    needs: [move-to-active]
    if: always()
    runs-on: <runner-label>
    steps:
      - uses: actions/checkout@<pinned-version>
      - uses: ./.github/actions/<workflow-toggle-adapter>
        with:
          state: enabled
          reason: runtime-migration-complete

  validate:
    needs:
      - discovery
      - disable-workflows
      - recreate-inactive
      - move-to-inactive
      - recreate-active
      - move-to-active
      - enable-workflows
    if: always()
    runs-on: <runner-label>
    steps:
      - shell: bash
        run: |
          test "${{ needs.enable-workflows.result }}" = "success"
          test "${{ needs.move-to-active.result }}" = "success"
```

## Replace Before Use

- runtime discovery script
- workflow toggle adapter
- deployment adapter
- migration adapter
- approval environment
- resume logic if partial retries are required
