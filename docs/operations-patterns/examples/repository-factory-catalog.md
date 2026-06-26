# Example: Repository Factory Catalog

Use a catalog like this when repositories should be created and governed from
declared state instead of manual settings.

```yaml
metadata:
  template_repository: "<template-repo>"
  default_visibility: "private"
  default_branch: "main"
  default_topics:
    - forge
    - operations

repositories:
  - name: "forge-runner-images"
    description: "Builds and tests Forge runner images."
    visibility: "private"
    template: "<template-repo>"
    topics:
      - runner-images
      - automation
    teams:
      readers:
        - "<team-readers>"
      writers:
        - "<team-writers>"
      maintainers:
        - "<team-maintainers>"
      admins:
        - "<team-admins>"
    branch_protection:
      required_reviews: 1
      dismiss_stale_reviews: true
      require_signed_commits: true
      required_checks:
        - "run-pre-commit"
        - "validate"
    rulesets:
      commit_message:
        pattern: "^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\\([\\w-]+\\))?(!)?: .+"
      pull_request:
        required_approving_review_count: 1
    webhooks:
      - name: "workflow-events"
        url: "<webhook-url>"
        events:
          - workflow_job
          - workflow_run
        active: true
        secret_ref: "<secret-reference>"
    metadata:
      owner: "<owning-team>"
      purpose: "image-factory"
      lifecycle: "active"
```

## Expected Automation

The repository factory should translate this catalog into:

- repository creation from template
- topics and metadata
- team permissions
- default branch
- branch protection
- repository rulesets
- required status checks
- webhook registration
- vulnerability or security settings where available

## Review Checklist

- Required checks are stable job names.
- `secret_ref` points to a secret source and is not a secret value.
- Template use is explicit.
- Team access is least privilege.
- Catalog diff is the only source of truth.
