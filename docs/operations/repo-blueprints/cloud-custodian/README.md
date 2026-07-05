# Repo: cloud-custodian

Purpose: clean stale AMIs, failed runner leftovers, old snapshots, and other
account hygiene items that should not live forever.

```text
cloud-custodian/
├── .github/workflows/cloud-custodian.yml
└── policies/
    ├── ami-cleanup.yml
    └── forge-leftovers.yml
```

Run in dry-run mode first. Move destructive policies to production only after
the reports match what operators expect.
