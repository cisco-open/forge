# Dynamic Action

This GitHub Action dynamically creates and runs a composite action based on provided inputs, allowing for flexible and reusable workflows.

## Inputs

- `action-uses`: The reference to the action to be dynamically executed (e.g., `actions/checkout@v2`).
- `action-with`: JSON-encoded string of inputs to pass to the dynamically executed action.

## Outputs

- `action-outputs`: JSON-encoded string of outputs from the dynamically executed action.

## Example Usage

```yaml
uses: ./.github/actions/dynamic-action
with:
  action-uses: 'actions/checkout@v5'
  action-with: '{"fetch-depth": "0"}'
```
