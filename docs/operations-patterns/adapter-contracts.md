# Adapter Contracts

Adapters isolate local implementation details from the reusable workflow shape.
Each adapter should have a small, stable interface so workflows stay readable
and private wiring can change without rewriting every automation.

## Common Rules

- Inputs and outputs must be documented in `action.yml`.
- Adapters should not print sensitive values.
- Adapters should fail fast when required environment or secrets are missing.
- Adapters should emit only stable outputs needed by later steps.
- Adapters should be testable with a dry-run or validation mode.

## `auth-adapter`

Purpose: prepare access for read-only and mutating operations.

```yaml
name: auth-adapter
description: Prepare local credentials for Forge operations.
inputs:
  environment:
    description: Target environment name.
    required: true
  mode:
    description: read-only or write.
    required: true
outputs:
  identity:
    description: Redacted identity label for summaries.
    value: ${{ steps.auth.outputs.identity }}
runs:
  using: composite
  steps:
    - id: auth
      shell: bash
      run: ./scripts/adapter-auth.sh "${{ inputs.environment }}" "${{ inputs.mode }}"
```

Expected behavior:

- `mode=read-only` cannot mutate remote state.
- `mode=write` fails unless the workflow environment approved the job.
- Output `identity` is safe to publish in a summary.

## `deployment-adapter`

Purpose: run dry-run and apply operations against one discovered unit.

```yaml
name: deployment-adapter
description: Run declared-state operations for one unit.
inputs:
  command:
    description: dry-run or apply.
    required: true
  path:
    description: Unit path.
    required: true
  summary-file:
    description: Markdown summary output path.
    required: false
    default: deployment-summary.md
runs:
  using: composite
  steps:
    - shell: bash
      run: |
        ./scripts/run-deployment.sh \
          --command "${{ inputs.command }}" \
          --path "${{ inputs.path }}" \
          --summary-file "${{ inputs.summary-file }}"
```

Expected behavior:

- `dry-run` exits nonzero on validation errors.
- `apply` exits nonzero on partial apply or unknown final state.
- Summary includes changed, unchanged, failed, and skipped resources.

## `registry-adapter`

Purpose: authenticate to the local image registry without exposing registry
details in reusable examples.

```yaml
name: registry-adapter
description: Prepare registry access for build or publish jobs.
inputs:
  mode:
    description: pull, push, or both.
    required: true
outputs:
  registry:
    description: Redacted registry label.
    value: ${{ steps.registry.outputs.registry }}
runs:
  using: composite
  steps:
    - id: registry
      shell: bash
      run: ./scripts/adapter-registry.sh "${{ inputs.mode }}"
```

Expected behavior:

- Pull-only mode cannot push.
- Push mode requires an approved publish environment.
- Output must not include tokens.

## `notification-adapter`

Purpose: publish summaries to the local notification or request system.

```yaml
name: notification-adapter
description: Publish a sanitized operation summary.
inputs:
  summary-file:
    required: true
  severity:
    required: false
    default: info
  title:
    required: true
runs:
  using: composite
  steps:
    - shell: bash
      run: |
        ./scripts/publish-summary.sh \
          --title "${{ inputs.title }}" \
          --severity "${{ inputs.severity }}" \
          --summary-file "${{ inputs.summary-file }}"
```

Expected behavior:

- Fails if the summary contains blocked sensitive patterns.
- Links back to workflow run or commit.
- Does not publish raw logs by default.

## `workflow-toggle-adapter`

Purpose: disable or enable competing automations during controlled migrations.

```yaml
name: workflow-toggle-adapter
description: Toggle selected workflows during migrations.
inputs:
  state:
    description: enabled or disabled.
    required: true
  reason:
    description: Human-readable maintenance reason.
    required: true
  workflow-group:
    description: Named workflow group to toggle.
    required: false
    default: migration-sensitive
runs:
  using: composite
  steps:
    - shell: bash
      run: |
        ./scripts/toggle-workflows.sh \
          --state "${{ inputs.state }}" \
          --reason "${{ inputs.reason }}" \
          --workflow-group "${{ inputs.workflow-group }}"
```

Expected behavior:

- Disable is idempotent.
- Enable always runs in a final `always()` cleanup job.
- Summary lists each workflow touched.
