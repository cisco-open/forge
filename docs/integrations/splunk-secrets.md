# Splunk Secrets

This page is for Splunk integrations only. Core Forge tenants use GitHub App
values from the tenant `config.yml` and the GitHub App PEM stored in SSM
Parameter Store by `scripts/update-github-app-secrets.sh`.

If you do not deploy `modules/integrations/splunk_*`, skip this page.

______________________________________________________________________

## Deploy the Splunk Secret Placeholders

```bash
cd examples/deployments/integrations/terragrunt/environments/prod/splunk_secrets
terragrunt plan
terragrunt apply
```

Then update the secret values in AWS Secrets Manager using your approved
rotation process. The examples use `/cicd/common/...`; change the names in
`config.yml` if your company uses another path.

______________________________________________________________________

## Splunk Secrets

| Secret name                                             | Used for                                                    | Required by                                                         |
| ------------------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------- |
| `/cicd/common/splunk_o11y_ingest_token_eks`             | EKS metrics, traces, and collector ingest.                  | `splunk_otel_eks`                                                   |
| `/cicd/common/splunk_o11y_ingest_token_aws_integration` | AWS integration metrics and events.                         | `splunk_o11y_aws_integration_common`, `splunk_o11y_aws_integration` |
| `/cicd/common/splunk_o11y_ingest_token_aws_billing`     | Billing telemetry ingest.                                   | `splunk_aws_billing`                                                |
| `/cicd/common/splunk_o11y_username`                     | Splunk Observability account login.                         | `splunk_o11y_aws_integration_common`                                |
| `/cicd/common/splunk_o11y_password`                     | Splunk Observability account password.                      | `splunk_o11y_aws_integration_common`                                |
| `/cicd/common/splunk_cloud_username`                    | Splunk Cloud Data Manager login.                            | `splunk_cloud_data_manager_common`, `splunk_cloud_data_manager`     |
| `/cicd/common/splunk_cloud_password`                    | Splunk Cloud Data Manager password.                         | `splunk_cloud_data_manager_common`, `splunk_cloud_data_manager`     |
| `/cicd/common/splunk_cloud_api_token`                   | Splunk Cloud dashboards, props, saved searches, and config. | `splunk_cloud_conf_shared`                                          |
| `/cicd/common/splunk_cloud_hec_token_eks`               | EKS log ingestion over HEC.                                 | `splunk_otel_eks`                                                   |

______________________________________________________________________

## External Secret Store

You can skip `splunk_secrets` if your platform already creates these AWS
Secrets Manager entries. In that case:

1. Keep the secret names stable.
1. Point each Splunk `config.yml` at the existing names.
1. Confirm the CI role and module runtime roles can read the secrets.
1. Deploy the Splunk modules that consume them.
