# Example: Dependency Automation Config

Use this for Renovate-style dependency automation. Keep the private package
access behind an adapter and keep the update behavior in declared config.

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "timezone": "UTC",
  "schedule": ["before 6am on monday"],
  "dependencyDashboard": true,
  "labels": ["dependencies"],
  "prConcurrentLimit": 5,
  "packageRules": [
    {
      "description": "Group GitHub Actions updates",
      "matchManagers": ["github-actions"],
      "groupName": "github-actions"
    },
    {
      "description": "Group image updates",
      "matchDatasources": ["docker"],
      "groupName": "container-images"
    },
    {
      "description": "Automerge low-risk patch updates after checks pass",
      "matchUpdateTypes": ["patch"],
      "automerge": false
    }
  ],
  "postUpgradeTasks": {
    "commands": [
      "./scripts/update-generated-docs.sh",
      "pre-commit run --files {{packageFile}}"
    ],
    "fileFilters": ["**/*.md", "**/*.yaml", "**/*.yml", "**/*.json"]
  }
}
```

## Workflow Wrapper Example

```yaml
name: Dependency Automation

on:
  schedule:
    - cron: "11 5 * * 1"
  workflow_dispatch:

permissions:
  contents: read
  pull-requests: write

jobs:
  update:
    runs-on: <runner-label>
    steps:
      - uses: actions/checkout@<pinned-version>
      - uses: ./.github/actions/<auth-adapter>
      - uses: ./.github/actions/<package-source-adapter>
      - name: Run dependency automation
        shell: bash
        run: |
          ./scripts/run-dependency-bot.sh \
            --config renovate.json \
            --summary-file dependency-summary.md
      - run: cat dependency-summary.md >> "$GITHUB_STEP_SUMMARY"
```

## Required Summary Fields

- update PRs opened or updated
- failed package lookups
- skipped managers
- generated files changed
- validation commands run

## Replace Before Use

- schedule
- package managers
- post-upgrade tasks
- private package source adapter
- dependency bot command
