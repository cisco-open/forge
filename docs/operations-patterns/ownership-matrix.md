# Ownership Matrix

Operations automation stays smooth only when each family has a clear owner,
backup, escalation route, and review expectation.

## Ownership Table

| Automation Family     | Primary Owner | Backup Owner | Reviewers        | Escalation     | Review Cadence  |
| --------------------- | ------------- | ------------ | ---------------- | -------------- | --------------- |
| Image factory         | `<owner>`     | `<backup>`   | `<review-group>` | `<escalation>` | weekly          |
| Container factory     | `<owner>`     | `<backup>`   | `<review-group>` | `<escalation>` | weekly          |
| IaC operations        | `<owner>`     | `<backup>`   | `<review-group>` | `<escalation>` | weekly          |
| Repository factory    | `<owner>`     | `<backup>`   | `<review-group>` | `<escalation>` | monthly         |
| Scheduled jobs        | `<owner>`     | `<backup>`   | `<review-group>` | `<escalation>` | monthly         |
| Policy hygiene        | `<owner>`     | `<backup>`   | `<review-group>` | `<escalation>` | monthly         |
| Dependency automation | `<owner>`     | `<backup>`   | `<review-group>` | `<escalation>` | weekly          |
| Migration flow        | `<owner>`     | `<backup>`   | `<review-group>` | `<escalation>` | before each use |

## Ownership Config Example

```yaml
automations:
  - name: image-factory
    family: image-factory
    owner: "<owner>"
    backup: "<backup>"
    reviewers:
      - "<review-group>"
    escalation: "<escalation>"
    review_cadence: weekly
    required_summary: true

  - name: repository-factory
    family: repository-factory
    owner: "<owner>"
    backup: "<backup>"
    reviewers:
      - "<review-group>"
    escalation: "<escalation>"
    review_cadence: monthly
    required_summary: true
```

## Review Expectations

- Owners review source-of-truth catalog changes.
- Backups can approve urgent rollback changes.
- Reviewers check validation evidence and summary output.
- Escalation contacts own blocked applies, broken schedules, and failed
  remediations.
- Any automation without a current owner should run in read-only mode only.
