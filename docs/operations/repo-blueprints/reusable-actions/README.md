# Repo: reusable-actions

Purpose: host shared composite actions used by the Forge operations repos. Keep
CI plumbing here so tenant, infra, image, container, and examples repos can call
one reviewed implementation instead of copying shell blocks into every workflow.

```text
reusable-actions/
└── .github/
    └── actions/
        ├── compute-terragrunt-layers-action/
        ├── dynamic-action/
        ├── global-lock-action/
        ├── mark-safe-directory-k8s-action/
        ├── terragrunt-deployment-action/
        ├── terragrunt-plan-comment-action/
        └── toggle-workflows-action/
```

## Actions

| Action                             | Use it for                                                   |
| ---------------------------------- | ------------------------------------------------------------ |
| `compute-terragrunt-layers-action` | Convert a Terragrunt DAG into execution layers.              |
| `dynamic-action`                   | Run a composite action selected at workflow runtime.         |
| `global-lock-action`               | Acquire and release a DynamoDB-backed workflow lock.         |
| `mark-safe-directory-k8s-action`   | Mark ARC/Kubernetes workspace paths as Git safe directories. |
| `terragrunt-deployment-action`     | Run Terragrunt plan/apply and comment plans on PRs.          |
| `terragrunt-plan-comment-action`   | Post a Terragrunt plan comment to a pull request.            |
| `toggle-workflows-action`          | Enable or disable workflows with a GitHub App token.         |

## Copy Notes

- Keep action versions pinned inside each action.
- Prefer local `./.github/actions/<name>` calls inside this repo.
- When another repo consumes this repo remotely, pin to a release tag or commit
  SHA.
- Keep credential setup actions narrow. Do not hide deployment logic inside a
  generic auth wrapper.
