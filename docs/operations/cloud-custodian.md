# Cloud Custodian

Use Cloud Custodian or an equivalent scheduled job to clean resources that can
outlive failed runner jobs, image builds, or tests.

## What To Manage

| Resource               | Why                                       |
| ---------------------- | ----------------------------------------- |
| old runner AMIs        | Prevent unbounded image growth.           |
| AMI snapshots          | Avoid storage cost after AMI deletion.    |
| stale EC2 instances    | Catch failed termination paths.           |
| stale launch templates | Remove leftovers from runner experiments. |
| old ECR tags           | Keep artifact repositories manageable.    |
| untagged resources     | Preserve ownership and cost attribution.  |

## Blueprint

Copy from:

```text
docs/operations/repo-blueprints/cloud-custodian
docs/operations/workflows/scheduled-maintenance.md
```

Run cleanup jobs in audit mode first. Move to destructive mode only after the
policy output is reviewed.
