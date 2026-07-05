# Repo: renovate-config

Purpose: run dependency automation for Forge operations repos. Keep Renovate
policy centralized, then let each repo extend it.

```text
renovate-config/
├── .github/workflows/renovate.yml
├── config/default.json
└── renovate.json
```

Use a real AWS session when Renovate needs to resolve AMI datasource entries.
For Dockerized Renovate, pass AWS files and env vars into the container.
