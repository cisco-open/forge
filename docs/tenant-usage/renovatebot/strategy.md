# Renovate Strategy

Renovate can run with a repo-local config, a central shared config, or both. Use
the smallest model that keeps ownership clear.

______________________________________________________________________

## Pick a Model

| Model                 | Use when                                                             | Avoid when                                      |
| --------------------- | -------------------------------------------------------------------- | ----------------------------------------------- |
| Repo-local config     | One repository owns its own dependency rules.                        | Many repos need the same rules.                 |
| Central shared config | A platform team owns common schedules, grouping, labels, and policy. | Repos have very different structures.           |
| Central runner repo   | One Renovate workflow manages many repositories.                     | Repo owners need isolated tokens and schedules. |
| Per-repo runner       | Each repo owns its own Renovate workflow and token.                  | You need one operational view of all updates.   |

Most teams should start repo-local. Move common rules into a central preset
after the same config has been copied a few times.

______________________________________________________________________

## Repo-Local Config

Create `renovate.json` in the repository:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended"
  ],
  "dependencyDashboard": true,
  "labels": [
    "dependencies"
  ],
  "packageRules": [
    {
      "matchManagers": [
        "github-actions"
      ],
      "groupName": "github actions"
    }
  ]
}
```

Use repo-local config for paths, test commands, reviewers, labels, and custom
managers that only make sense for that repo.

______________________________________________________________________

## Central Shared Config

Create a central repository such as `your-org/renovate-config` with
`default.json`:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended",
    ":semanticCommits",
    ":rebaseStalePrs"
  ],
  "dependencyDashboard": true,
  "labels": [
    "dependencies"
  ],
  "prHourlyLimit": 2,
  "schedule": [
    "before 5am on monday"
  ]
}
```

Then each managed repo can extend it:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "github>your-org/renovate-config"
  ],
  "reviewers": [
    "team:platform-reviewers"
  ]
}
```

Keep secrets out of the central config. Tokens, registry credentials, and AWS
roles belong in the workflow runtime.

______________________________________________________________________

## Central Runner Repo

Use a central runner repo when one team operates Renovate for many repos.

`renovate.json` in the runner repo:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "github>your-org/renovate-config"
  ],
  "repositories": [
    "your-org/service-a",
    "your-org/service-b",
    "your-org/iac-live"
  ]
}
```

Central runner repos are useful when:

- one bot identity owns dependency PRs;
- private registry or AWS lookup setup is shared;
- support teams need one log artifact and one schedule;
- repo owners still review and merge their own PRs.

______________________________________________________________________

## What Belongs Where

| Setting type                 | Central config      | Repo-local config | Workflow runtime |
| ---------------------------- | ------------------- | ----------------- | ---------------- |
| Default schedules            | Yes                 | Override only     | No               |
| Labels and semantic commits  | Yes                 | Override only     | No               |
| Repository list              | Central runner only | No                | No               |
| Reviewers                    | Usually no          | Yes               | No               |
| Path-specific regex managers | Usually no          | Yes               | No               |
| Post-upgrade commands        | Usually no          | Yes               | No               |
| GitHub token                 | No                  | No                | Yes              |
| AWS role and region          | No                  | No                | Yes              |
| Private registry credentials | No                  | No                | Yes              |

______________________________________________________________________

## Rollout Sequence

1. Enable Renovate for one repo manually with `workflow_dispatch`.
1. Check the log artifact and the first PRs.
1. Add grouping and schedules.
1. Add private registry or AWS access only when a dependency needs it.
1. Move repeated rules into a central preset.
1. Add more repositories to the central runner only after the first repo is
   quiet and predictable.

______________________________________________________________________

## Review Rules

- Major upgrades should get explicit owner review.
- IaC dependency updates should include a plan or policy check.
- Runner image or Docker changes should include a smoke test.
- Post-upgrade commands should be narrow and reviewed like code.
- Keep automerge off until the repository has reliable tests and rollback.
