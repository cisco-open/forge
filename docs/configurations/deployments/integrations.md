# Integrations Deployment

Integrations connect Forge to external systems. They are optional. Do not start
a Forge install here; deploy the platform path first, then add the integrations
you actually use.

Deploy root:

```text
examples/deployments/integrations/terragrunt
```

If your company does not use Splunk, skip every `splunk_*` directory and use
only the non-Splunk rows below.

______________________________________________________________________

## Non-Splunk Integrations

| Module                                                            | Example directory                                              | Use when                                           |
| ----------------------------------------------------------------- | -------------------------------------------------------------- | -------------------------------------------------- |
| `modules/integrations/github_webhook_relay_destination`           | `environments/prod/github_webhook_relay_destination`           | Another account or bus receives forwarded events.  |
| `modules/integrations/github_webhook_relay_destination_receivers` | `environments/prod/github_webhook_relay_destination_receivers` | Downstream receivers need a bundled destination.   |
| `modules/integrations/teleport`                                   | `environments/prod/regions/eu-west-1/teleport`                 | EKS access uses Teleport agents or audited access. |

These integrations may still require helper resources such as S3 buckets,
Secrets Manager entries, CloudFormation roles, or externally managed
equivalents.

______________________________________________________________________

## Splunk Integrations

Splunk modules are documented separately because they have their own credential
and dependency flow:

- [Splunk Integration](../../integrations/splunk.md)
- [Splunk Secrets](../../integrations/splunk-secrets.md)

Skip both pages if your observability stack is not Splunk.

______________________________________________________________________

## What You Edit

| File                                                                      | Change                                                      |
| ------------------------------------------------------------------------- | ----------------------------------------------------------- |
| `_global_settings/_global.yml`                                            | Team, product, project, GitHub org, and owner defaults.     |
| `environments/prod/_environment_wide_settings/_environment.yml`           | AWS account, default region, AWS profile, and remote state. |
| `environments/prod/github_webhook_relay_destination/config.yml`           | Destination EventBridge and reader role settings.           |
| `environments/prod/github_webhook_relay_destination_receivers/config.yml` | Receiver bundle configuration.                              |
| `environments/prod/regions/eu-west-1/teleport/config.yml`                 | Teleport cluster, namespace, chart, and EKS access values.  |
| `release_versions.yml`                                                    | Integration module sources, refs, and `module_path` values. |

Templates live under `examples/templates/integrations`.

______________________________________________________________________

## Deploy One Integration

Teleport:

```bash
cd examples/deployments/integrations/terragrunt/environments/prod/regions/eu-west-1/teleport
terragrunt plan
terragrunt apply
```

Plan the full integration environment only after single-module plans are clean:

```bash
cd examples/deployments/integrations/terragrunt/environments/prod
terragrunt plan --all
```

______________________________________________________________________

## Dependency Notes

- Webhook relay source is internal to
  `modules/platform/forge_runners/github_webhook_relay/source`; enable it from
  the platform tenant config.
- Webhook relay destination must exist before the platform source forwards
  events to a different account.
- Teleport needs EKS access. Use an existing cluster or deploy
  [Infra / EKS](./infra.md).
- Splunk modules can depend on `splunk_secrets`, helper buckets, and
  CloudFormation helper roles. Use externally managed resources if your company
  already provides them.
