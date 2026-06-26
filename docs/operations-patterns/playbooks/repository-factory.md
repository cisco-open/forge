# Playbook: Repository Factory

## Goal

Create and maintain repositories from a catalog so repository settings are
reviewed, repeatable, and recoverable.

## Use When

- Creating a new Forge operations repository.
- Updating team access.
- Changing branch protection or required checks.
- Adding repository metadata, topics, autolinks, or webhooks.
- Creating a new repository from a template.

## Inputs

- Repository catalog entry.
- Template repository placeholder.
- Team access model.
- Required checks.
- Branch protection and ruleset policy.
- Webhook or integration contract.

## Skeleton

1. Add or update one catalog entry.
1. Validate catalog schema.
1. Dry-run repository changes.
1. Review planned changes for create, update, access, protection, and webhook
   resources.
1. Apply only after review.
1. Verify repository settings after apply.
1. Record follow-up work that cannot be safely automated.

## Catalog Fields

| Field             | Purpose                                                    |
| ----------------- | ---------------------------------------------------------- |
| `name`            | Repository name.                                           |
| `description`     | Reviewer-readable purpose.                                 |
| `visibility`      | Public, private, or internal visibility policy.            |
| `template`        | Optional source template.                                  |
| `topics`          | Search and ownership tags.                                 |
| `teams`           | Readers, writers, maintainers, and administrators.         |
| `required_checks` | Stable required status checks.                             |
| `rulesets`        | Pull request, signature, commit-message, and branch rules. |
| `webhooks`        | Event relay contracts.                                     |
| `metadata`        | Custom fields used for inventory and reporting.            |

## Review Checklist

- Required checks match stable workflow job names.
- Repository creation cannot accidentally destroy existing repositories.
- Team access follows least privilege.
- Webhook secrets are referenced, never committed.
- Template use is intentional and documented.
- Manual follow-ups are tracked.

## Definition Of Done

- Catalog diff clearly describes the repository change.
- Dry-run shows only intended changes.
- Applied repository settings match the catalog.
- Follow-up access or secret steps are recorded.

## Common Failures

- Managing repository settings by hand after the catalog exists.
- Requiring dynamic workflow matrix jobs in branch protection.
- Hiding one-off access grants outside the catalog.
