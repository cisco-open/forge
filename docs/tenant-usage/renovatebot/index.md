# Renovate Workflow Setup

Use this page when a repo needs Renovate to run on a Forge runner. For simple
single-repo updates, start with [Dependabot](../dependency-management.md)
instead.

Renovate needs two files:

```text
.github/workflows/renovate.yml
renovate.json
```

______________________________________________________________________

## Prerequisites

| Requirement          | What to prepare                                                        |
| -------------------- | ---------------------------------------------------------------------- |
| Forge runner labels  | A runner that can reach GitHub, registries, and any private endpoints. |
| Renovate token       | A GitHub App token or bot PAT with access to the target repositories.  |
| Repository list      | The repos Renovate is allowed to update.                               |
| Optional AWS access  | Role ARN if Renovate must query AMIs, ECR, private modules, or S3.     |
| Optional GPG signing | Bot signing key if your branch protection requires signed commits.     |

Store secrets in GitHub Actions secrets or fetch them from AWS Secrets Manager
inside the workflow. Do not commit tokens in `renovate.json`.

______________________________________________________________________

## Workflow

Create `.github/workflows/renovate.yml`:

```yaml
---
name: Renovate

on:
  schedule:
    - cron: 0 4 * * 1
  workflow_dispatch:

permissions: {}

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: false

jobs:
  renovate:
    name: Run Renovate
    runs-on:
      - self-hosted
      - type:large
      - x64
      - ec2
      - env:ops-prod
      - tnt:acme
    permissions:
      contents: read
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          persist-credentials: false

      - name: Prepare Renovate logs
        shell: bash
        run: install -d -m 755 "${RUNNER_TEMP}/renovate-logs"

      - name: Run Renovate
        uses: renovatebot/github-action@<approved-pinned-ref>
        with:
          configurationFile: renovate.json
          token: ${{ secrets.RENOVATE_TOKEN }}
        env:
          LOG_LEVEL: warn
          LOG_FILE: /tmp/renovate-logs/renovate.log
          LOG_FILE_FORMAT: json
          LOG_FILE_LEVEL: debug
          RENOVATE_ONBOARDING: 'false'

      - name: Upload Renovate logs
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: renovate-logs
          path: ${{ runner.temp }}/renovate-logs/
          if-no-files-found: warn
          retention-days: 14
```

Replace:

| Placeholder             | Replace with                                    |
| ----------------------- | ----------------------------------------------- |
| `type:large`            | Tenant runner type for dependency jobs.         |
| `env:ops-prod`          | Your tenant environment label.                  |
| `tnt:acme`              | Your tenant label.                              |
| `<approved-pinned-ref>` | Your approved Renovate action tag or SHA.       |
| `RENOVATE_TOKEN`        | GitHub Actions secret containing the bot token. |

Use a schedule that matches your review capacity. Weekly is usually a better
first default than every few hours.

______________________________________________________________________

## Optional AWS Access

Add this before the Renovate step when Renovate needs AWS access for AMI lookup,
private ECR, private modules, or S3:

```yaml
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/renovate-readonly
          aws-region: eu-west-1
          role-duration-seconds: 3600
          role-chaining: true
```

The role must be allowed by the Forge tenant config and trusted by the target
AWS account. If your company uses GitHub OIDC instead of runner-role chaining,
use the OIDC pattern required by that account.

______________________________________________________________________

## Optional AWS Secrets Manager Token

If the token lives in AWS Secrets Manager, fetch it into an environment variable
and pass that environment variable to Renovate:

```yaml
      - name: Read Renovate token
        uses: aws-actions/aws-secretsmanager-get-secrets@v2
        with:
          secret-ids: |
            RENOVATE_TOKEN,/cicd/common/renovate_token

      - name: Run Renovate
        uses: renovatebot/github-action@<approved-pinned-ref>
        with:
          configurationFile: renovate.json
          token: ${{ env.RENOVATE_TOKEN }}
```

Do not reference `${{ secrets.RENOVATE_TOKEN }}` when the token was fetched
into the environment by a previous step.

______________________________________________________________________

## Renovate Config

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
  "onboarding": false,
  "dependencyDashboard": true,
  "repositories": [
    "your-org/your-repo"
  ],
  "labels": [
    "dependencies",
    "renovate"
  ],
  "prHourlyLimit": 2,
  "packageRules": [
    {
      "matchUpdateTypes": [
        "major"
      ],
      "addLabels": [
        "major-upgrade"
      ],
      "automerge": false
    },
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

For a self-contained repo, keep only the current repository in `repositories`.
For a central Renovate runner repo, add every repository the bot should manage.

______________________________________________________________________

## Custom Regex Managers

Use custom managers only for dependencies Renovate cannot discover by default.
Example for version comments in YAML:

```json
{
  "customManagers": [
    {
      "customType": "regex",
      "fileMatch": [
        "(^|/)versions\\.ya?ml$"
      ],
      "matchStrings": [
        "# renovate: datasource=(?<datasource>\\S+) depName=(?<depName>\\S+)\\n\\s*version: (?<currentValue>\\S+)"
      ],
      "versioningTemplate": "semver"
    }
  ]
}
```

Then annotate the file Renovate should update:

```yaml
# renovate: datasource=github-releases depName=opentofu/opentofu
version: 1.10.0
```

Keep regex managers narrow. Broad patterns create noisy or wrong PRs.

______________________________________________________________________

## Validate Before Enabling the Schedule

```bash
jq . renovate.json
```

Run Renovate manually first with `workflow_dispatch`, then inspect:

- Renovate log artifact.
- Repositories matched by the config.
- PR titles, labels, branches, and reviewers.
- Any private registry, AWS, or GitHub authentication failures.

Enable the schedule only after the manual run produces the expected PR shape.
