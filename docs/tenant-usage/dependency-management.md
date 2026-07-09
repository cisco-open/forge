# Dependency Management

Use dependency automation to keep workflow actions, containers, language
packages, and IaC dependencies moving without turning every update into manual
inventory work.

Forge does not require one tool. Pick the smallest tool that covers the repo.

______________________________________________________________________

## Choose a Tool

| Need                                              | Use                    | Notes                                               |
| ------------------------------------------------- | ---------------------- | --------------------------------------------------- |
| GitHub-native security and version updates        | Dependabot             | Best first step for one repository.                 |
| GitHub Actions, Docker, Python, Terraform basics  | Dependabot             | Works with simple repo-local config.                |
| Grouped updates, custom schedules, or many repos  | Renovate               | Better for platform teams and multi-repo ownership. |
| AMI, custom regex, HCL, or private registry logic | Renovate               | Needs explicit config and usually a bot token.      |
| Centralized dependency policy across many repos   | Renovate shared config | Keep common rules in one config repo.               |

Do not let Dependabot and Renovate update the same dependency family in the
same repository unless you intentionally split ownership.

______________________________________________________________________

## Dependabot Starter

Create `.github/dependabot.yml`:

```yaml
---
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
    groups:
      github-actions:
        patterns:
          - '*'
    labels:
      - dependencies
      - github-actions

  - package-ecosystem: docker
    directory: /
    schedule:
      interval: weekly
    groups:
      docker:
        patterns:
          - '*'
    labels:
      - dependencies
      - docker

  - package-ecosystem: uv
    directory: /
    schedule:
      interval: weekly
    groups:
      python:
        patterns:
          - '*'
    labels:
      - dependencies
      - python

  - package-ecosystem: terraform
    directory: /
    schedule:
      interval: weekly
    groups:
      terraform:
        patterns:
          - '*'
    labels:
      - dependencies
      - terraform
```

Remove ecosystems that do not exist in the repo. For monorepos, add one entry
per directory that contains dependency files. Use `uv` for repositories that
commit `pyproject.toml` and `uv.lock`; use `pip` only for requirements-file
projects.

______________________________________________________________________

## Renovate Starter

Use Renovate when you need more control than Dependabot gives you.

Create `renovate.json`:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended",
    ":semanticCommits",
    ":semanticCommitScope(deps)",
    ":rebaseStalePrs"
  ],
  "dependencyDashboard": true,
  "labels": [
    "dependencies"
  ],
  "prHourlyLimit": 2,
  "schedule": [
    "before 5am on monday"
  ],
  "packageRules": [
    {
      "matchManagers": [
        "github-actions"
      ],
      "groupName": "github actions"
    },
    {
      "matchManagers": [
        "dockerfile",
        "docker-compose"
      ],
      "groupName": "container images"
    },
    {
      "matchManagers": [
        "terraform",
        "terragrunt"
      ],
      "groupName": "terraform and opentofu"
    }
  ]
}
```

Then add the Forge-runner workflow from
[Renovate Workflow Setup](./renovatebot/index.md).

______________________________________________________________________

## Required Review Gates

Use at least these checks before merging dependency PRs:

| Change type                    | Check                                            |
| ------------------------------ | ------------------------------------------------ |
| GitHub Actions                 | Workflow lint or repository action policy check. |
| Terraform/OpenTofu/Terragrunt  | `fmt`, `validate`, policy scan, and plan.        |
| Docker or runner image changes | Build, scan, and smoke test.                     |
| Python or application packages | Unit tests and dependency vulnerability scan.    |
| Renovate config changes        | JSON validation and a Renovate dry run.          |

For pull requests, the dependency review workflow is a useful backstop:

```yaml
---
name: Dependency Review

on:
  pull_request:
    branches:
      - main

permissions: {}

jobs:
  dependency-review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false

      - uses: actions/dependency-review-action@v5
        with:
          comment-summary-in-pr: always
```

Pin action refs to approved SHAs when your repository policy requires it.

______________________________________________________________________

## Operating Rules

- Keep update PRs small enough to review.
- Separate major upgrades from routine patch and minor updates.
- Disable automerge until the repo has reliable tests and rollback.
- Route dependency PRs to owners who understand the stack.
- For IaC repos, never merge a dependency PR without a plan against the target
  environment.

Use [Renovate Strategy](./renovatebot/strategy.md) when deciding between a
central config and repo-local config.
