# 🔐 Secrets Inventory

The following secrets **must exist in AWS Secrets Manager** under the fixed prefix `/cicd/common`.
They can be created via `module.integration.splunk_secrets`, custom modules, or any other process — **the only requirement is that they exist before applying dependent modules.**

| Secret Name                                             | Description                                | Required By Modules                                                                                       |
| ------------------------------------------------------- | ------------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| `/cicd/common/splunk_o11y_ingest_token_eks`             | Splunk Observability Access Token (Ingest) | `modules/infra/eks`,                                                                                      |
| `/cicd/common/splunk_o11y_ingest_token_aws_integration` | Splunk Observability Access Token (Ingest) | `integrations/splunk_o11y_aws_integration`                                                                |
| `/cicd/common/splunk_o11y_ingest_token_aws_billing`     | Splunk Observability Access Token (Ingest) | `integrations/splunk_aws_billing`                                                                         |
| `/cicd/common/splunk_o11y_username`                     | Splunk Observability Username              | `modules/integrations/splunk_o11y_aws_integration_common`                                                 |
| `/cicd/common/splunk_o11y_password`                     | Splunk Observability Password              | `modules/integrations/splunk_o11y_aws_integration_common`                                                 |
| `/cicd/common/splunk_cloud_username`                    | Splunk Cloud Username                      | `modules/integrations/splunk_cloud_data_manager`, `modules/integrations/splunk_cloud_data_manager_common` |
| `/cicd/common/splunk_cloud_password`                    | Splunk Cloud Password                      | `modules/integrations/splunk_cloud_data_manager`, `modules/integrations/splunk_cloud_data_manager_common` |
| `/cicd/common/splunk_cloud_api_token`                   | Splunk Cloud API Token                     | `modules/integrations/splunk_cloud_conf_shared`                                                           |
| `/cicd/common/splunk_cloud_hec_token_eks`               | Splunk Cloud HEC Token for EKS             | `modules/infra/eks`                                                                                       |

## 🔑 Splunk Tokens Overview

Splunk integrations require authentication tokens securely stored in AWS Secrets Manager and injected into modules at runtime.

### 🔸 HEC Token (HTTP Event Collector)

- **Token:** `/cicd/common/splunk_cloud_hec_token_eks` — See [Splunk HEC Docs](https://docs.splunk.com/Documentation/SplunkCloud/latest/Data/UsetheHTTPEventCollector)
- **Purpose:** Authenticates log ingestion over HTTP from EKS via the [Splunk OpenTelemetry Collector Helm Chart](https://signalfx.github.io/splunk-otel-collector-chart).
- **Used By:** `infra/eks` (log forwarding to Splunk Cloud)

### 🔸 Observability (o11y) Access Token

- **Token:** `/cicd/common/splunk_o11y_ingest_token_*`

- **Purpose:** Enables ingestion of metrics, traces, and logs into Splunk Observability Cloud.

- **Used By:**

  - `modules/infra/eks` (via [Splunk OpenTelemetry Collector Helm Chart](https://signalfx.github.io/splunk-otel-collector-chart))
  - `modules/integrations/splunk_o11y_aws_integration` (via AWS CloudFormation — see [Splunk Docs](https://docs.splunk.com/observability/en/gdi/get-data-in/connect/aws/aws-cloudformation.html#aws-cloudformation))
  - `modules/integrations/splunk_aws_billing`

### 🔸 Splunk Cloud API Token

- **Token:** `/cicd/common/splunk_cloud_api_token` — used to authenticate API requests against Splunk Cloud endpoints.

- **Purpose:** Enables integration modules to programmatically configure Splunk Cloud, manage dashboards, and update settings.

- **Used By:**

  - `modules/integrations/splunk_cloud_conf_shared` (automates Splunk Cloud configuration and dashboard management)
