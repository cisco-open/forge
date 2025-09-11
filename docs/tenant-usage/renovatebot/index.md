# **Automated Dependency Management with RenovateBot Using GitHub Actions**

<!-- toc -->

- [**Automated Dependency Management with RenovateBot Using GitHub Actions**](#automated-dependency-management-with-renovatebot-using-github-actions)
  - [RenovateBot GitHub Actions Workflow Setup](#renovatebot-github-actions-workflow-setup)
    - [File name: `renovatebot-github-actions.yml`](#file-name-renovatebot-github-actionsyml)
    - [Key Parts Breakdown](#key-parts-breakdown)
  - [Renovate Configuration File (`config.json`)](#renovate-configuration-file-configjson)
    - [File name: `config.json`](#file-name-configjson)
    - [Key Sections Breakdown](#key-sections-breakdown)
  - [Renovate Configuration File (`default.json`)](#renovate-configuration-file-defaultjson)
    - [File name: `default.json`](#file-name-defaultjson)
    - [Key Sections Breakdown](#key-sections-breakdown-1)
  - [Security Considerations](#security-considerations)

<!-- tocstop -->

This guide explains how to integrate **RenovateBot** with a self-hosted **GitHub Actions** workflow for automated dependency management, with configurations for **custom setups** and **secure secrets management** using **AWS Secrets Manager**.

## RenovateBot GitHub Actions Workflow Setup

### File name: `renovatebot-github-actions.yml`

This file configures a GitHub Actions workflow that integrates RenovateBot for automated dependency management.

```yaml
name: RenovateBot
on:
  schedule:
    - cron: "0 */4 * * *"  # Runs every 4 hours
  workflow_dispatch:  # Manual trigger option from GitHub UI

jobs:
  renovate:
    runs-on:
      - self-hosted
      - x64
      - type: large
      - env: ops-prod

    steps:
      - name: Checkout Repository
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@ececac1a45f3b08a01d2dd070d28d111c5fe6722 # v4.1.0
        with:
          role-to-assume: arn:aws:iam::<aws-account-id>:role/<iam-role>
          aws-region: <aws-region>
          role-duration-seconds: 900

      - name: Get Secrets
        uses: aws-actions/aws-secretsmanager-get-secrets@fbd65ea98e018858715f591f03b251f02b2316cb # v2.0.8
        with:
          secret-ids: |
            GITHUB_TOKEN,/cicd/common/github_cloud_repo_access
            GITHUB_GPG_KEY,/cicd/common/github_gpg_key

      - name: Add Secrets to Config
        run: |
          sed -i 's/%GITHUB_TOKEN%/${{ secrets.GITHUB_TOKEN }}/g' config.json
          git config --global \
            url."https://oauth2:@github.com/".insteadOf \
            "https://github.com/"


      - name: Self-hosted Renovate
        uses: renovatebot/github-action@v40.3.4
        with:
          configurationFile: config.json
        env:
          LOG_LEVEL: debug
          RENOVATE_GIT_AUTHOR: <Name> <<your bot email>>  # Update with bot's email
          RENOVATE_ONBOARDING: false
          RENOVATE_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          RENOVATE_GIT_PRIVATE_KEY: ${{ secrets.GITHUB_GPG_KEY }}
```

### Key Parts Breakdown

1. **Workflow Triggers**:

- The workflow runs every 4 hours (`cron`), and it can be manually triggered (`workflow_dispatch`).

2. **Jobs**:

- **Checkout Repository**: Fetches the repository code.
- **Configure AWS Credentials**: Sets AWS credentials using IAM roles for cross-account access.
- **Get Secrets**: Retrieves necessary secrets from **AWS Secrets Manager**.
- **Install Terraform Providers**: Installs required Terraform providers.
- **Self-hosted Renovate**: Runs RenovateBot with the specified `config.json` file.

3. **Secrets Management**:

- Secrets (e.g., GitHub tokens, GPG keys, registry credentials) are securely fetched from **AWS Secrets Manager** and injected as GitHub secrets.

______________________________________________________________________

## Renovate Configuration File (`config.json`)

### File name: `config.json`

```json
{
    "$schema": "https://docs.renovatebot.com/renovate-schema.json",
    "endpoint": "https://api.github.com/",
    "prHourlyLimit": 2,
    "allowedPostUpgradeCommands": [
    ],
    "repositories": [
        "<your org>/my-repo1",
        "<your org>/my-repo2"
    ],
    "hostRules": [
        {
            "hostType": "github",
            "matchHost": "github.com",
            "token": "%GITHUB_TOKEN%"
        },
    ]
}
```

### Key Sections Breakdown

1. **`$schema`**:

   - Ensures the configuration follows Renovate’s schema.

1. **`endpoint`**:

   - Specifies the GitHub API endpoint for Renovate to communicate with. Can be customized if using a self-hosted GitHub instance.

1. **`prHourlyLimit`**:

   - Limits the number of pull requests Renovate can create per hour. Set to `2` in this example.

1. **`allowedPostUpgradeCommands`**:

   - Defines custom scripts to run after dependencies are upgraded, ensuring proper post-upgrade handling.

1. **`repositories`**:

   - Lists the repositories managed by Renovate. Add repositories as needed.

1. **`hostRules`**:

   - Configures authentication with different host types, such as GitHub (cloud and on-prem) and a Docker registry.

______________________________________________________________________

## Renovate Configuration File (`default.json`)

### File name: `default.json`

```json
{
    "$schema": "https://docs.renovatebot.com/renovate-schema.json",
    "baseBranches": [
        "main"
    ],
    "extends": [
        "config:base",
        ":rebaseStalePrs",
        ":semanticCommits",
        ":semanticCommitScope(deps)"
    ],
    "reviewers": [
        "@<your org>/<team name>"
    ],
    "labels": [
        "Dependencies",
        "Renovate"
    ],
    "customManagers": [
        {
            "customType": "regex",
            "fileMatch": [
                "^*\\.tf$"
            ],
            "matchStrings": [
                "required_version\\s=\\s\">= (?<currentValue>.*?)\""
            ],
            "depNameTemplate": "opentofu/opentofu",
            "datasourceTemplate": "github-releases"
        },
        {
            "fileMatch": [
                "^*\\.yml$",
                "^*\\.yaml$"
            ],
            "matchStrings": [
                "# renovate: datasource=(?<datasource>\\S+) depName=(?<depName>\\S+) registryUrl=(?<registryUrl>\\S+)( extractVersion=(?<extractVersion>.+?))?( versioning=(?<versioning>.*?))?\\n.*?version: (?<currentValue>.*)?\\s"
            ],
            "versioningTemplate": "{{#if versioning}}{{{versioning}}}{{else}}semver{{/if}}"
        },
        {
            "fileMatch": [
                "(^|/)*\\.hcl$"
            ],
            "matchStrings": [
                "# renovate: datasource=(?<datasource>\\S+) depName=(?<depName>\\S+) registryUrl=(?<registryUrl>\\S+)( extractVersion=(?<extractVersion>.+?))?( versioning=(?<versioning>.*?))?\\n.*?version( = \"(?<currentValue>.*)\")?\\s"
            ],
            "versioningTemplate": "{{#if versioning}}{{{versioning}}}{{else}}semver{{/if}}"
        },
        {
            "fileMatch": [
                "^*\\.yml$",
                "^*\\.yaml$"
            ],
            "matchStrings": [
                "(?<depName>[^\\s=]+)==(?<currentValue>.*?[^\\s]+)"
            ],
            "datasourceTemplate": "pypi"
        },
        {
            "fileMatch": [
                "Dockerfile$"
            ],
            "matchStrings": [
                "# renovate: datasource=(?<datasource>\\S+) depName=(?<depName>\\S+) registryUrl=(?<registryUrl>\\S+)( extractVersion=(?<extractVersion>.+

?))?( versioning=(?<versioning>.*?))?\\n.*?version: (?<currentValue>.*)?\\s"
            ],
            "versioningTemplate": "{{#if versioning}}{{{versioning}}}{{else}}semver{{/if}}"
        }
    ]
}
```

### Key Sections Breakdown

1. **`baseBranches`**:

- Configures Renovate to operate only on the `main` branch (adjustable as needed).

2. **`extends`**:

- Includes predefined settings for semantic commits, rebase stale PRs, etc.

3. **`reviewers`**:

- Specifies the GitHub teams or users to review pull requests created by Renovate.

4. **`labels`**:

- Automatically labels pull requests with "Dependencies" and "Renovate".

5. **`customManagers`**:

- Defines custom dependency managers using regex for specific file types like Terraform (`.tf`), YAML (`.yml`/`.yaml`), and HCL (`.hcl`).

______________________________________________________________________

## Security Considerations

- **Avoid exposing sensitive information**: Ensure that secrets, such as API tokens and registry credentials, are never hardcoded or logged. Use AWS Secrets Manager or GitHub Secrets for secure management.
- **Limit access**: Set strict IAM roles and permissions to minimize exposure of secrets and control access to sensitive workflows.
