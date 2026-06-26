# Example: Policy Hygiene Job

Use this for Custodian-style policy scans or remediations. The default path is
read-only. Remediation must be explicit and protected.

```yaml
name: Policy Hygiene

on:
  schedule:
    - cron: "43 4 * * *"
  workflow_dispatch:
    inputs:
      mode:
        type: choice
        options: [scan, remediate]
        default: scan
      policy_set:
        type: string
        default: "policies/default"

permissions:
  contents: read

concurrency:
  group: policy-hygiene-${{ inputs.policy_set || 'default' }}
  cancel-in-progress: false

jobs:
  scan:
    runs-on: <runner-label>
    steps:
      - uses: actions/checkout@<pinned-version>
      - uses: ./.github/actions/<auth-adapter>
      - name: Run policy scan
        shell: bash
        run: |
          ./scripts/policy-hygiene.sh \
            --mode scan \
            --policy-set "${{ inputs.policy_set || 'policies/default' }}" \
            --summary-file policy-summary.md
      - run: cat policy-summary.md >> "$GITHUB_STEP_SUMMARY"

  remediate:
    needs: scan
    if: github.event_name == 'workflow_dispatch' && inputs.mode == 'remediate'
    runs-on: <runner-label>
    environment: policy-remediation
    steps:
      - uses: actions/checkout@<pinned-version>
      - uses: ./.github/actions/<auth-adapter>
      - name: Run approved remediation
        shell: bash
        run: |
          ./scripts/policy-hygiene.sh \
            --mode remediate \
            --policy-set "${{ inputs.policy_set }}" \
            --summary-file remediation-summary.md
      - run: cat remediation-summary.md >> "$GITHUB_STEP_SUMMARY"
```

## Policy Set Example

```yaml
policies:
  - name: missing-owner-tag
    mode: scan
    severity: medium
    resource: "<resource-kind>"
    filters:
      - field: "tags.owner"
        op: missing
    remediation:
      enabled: false
      action: "notify-owner"

  - name: expired-temporary-resource
    mode: scan
    severity: high
    resource: "<resource-kind>"
    filters:
      - field: "tags.expires_at"
        op: before_today
    remediation:
      enabled: true
      action: "delete-after-approval"
```

## Replace Before Use

- policy engine command
- policy schema
- remediation approval environment
- resource kinds
- notification adapter
