## 📦 Module Overview

Below is a summary of the main modules in `modules/infra/`, `modules/core/arc/`, `modules/platform/`, and `modules/integrations/`:

| Module/Path                                                      | Purpose                                                                                                   | Key Requirements / Notes                                                                                   |
|------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------|
| **infra**                                                        |                                                                                                           |                                                                                                            |
| `infra/ami_policy`                                               | Manages AMI sharing and policy controls for runner images                                                 | —                                                                                                          |
| `infra/ami_sharing`                                              | Shares AMIs across accounts or regions                                                                    | —                                                                                                          |
| `infra/billing`                                                  | Sets up billing alarms and notifications                                                                  | —                                                                                                          |
| `infra/budget`                                                   | Manages AWS Budgets for cost control                                                                      | —                                                                                                          |
| `infra/cloud_custodian`                                          | Applies Cloud Custodian policies for resource governance                                                  | —                                                                                                          |
| `infra/cloud_formation`                                          | Grants CloudFormation permissions needed by integration modules                                           | Required for Splunk and Observability integrations                                                         |
| `infra/ecr`                                                      | Provisions ECR repositories for runner images                                                             | —                                                                                                          |
| `infra/eks`                                                      | Provisions EKS clusters for Kubernetes-based runners                                                      | Requires secrets for Splunk integration                                                                    |
| `infra/forge_subscription`                                       | Manages Forge subscription and related resources                                                          | —                                                                                                          |
| `infra/opt_in_regions`                                           | Enables AWS regions for use                                                                               | —                                                                                                          |
| `infra/secrets`                                                  | Manages sensitive values via AWS Secrets Manager                                                          | Must create `/tf/splunk_access_ingest_token` and `/tf/splunk_cloud_hec_token_eks` secrets                  |
| `infra/service_linked_roles`                                     | Ensures AWS service-linked roles exist (e.g., for EC2 Spot support)                                       | Must allow creation of EC2 Spot service-linked role in the account                                         |
| `infra/storage`                                                  | Provisions required S3 buckets for integrations (e.g., Splunk Cloud Data Manager)                         | Used by Splunk and other integrations                                                                      |
| **core/arc**                                                     |                                                                                                           |                                                                                                            |
| `core/arc`                                                       | Deploys and manages the Actions Runner Controller (ARC) for EKS-based runners                             | —                                                                                                          |
| `core/arc/scale_set`                                             | Manages ARC scale sets for dynamic runner scaling                                                         | —                                                                                                          |
| `core/arc/scale_set_controller`                                  | Controls ARC scale set lifecycle and configuration                                                        | —                                                                                                          |
| **platform**                                                     |                                                                                                           |                                                                                                            |
| `platform/arc_deployment`                                        | Deploys ARC and related resources                                                                         | —                                                                                                          |
| `platform/ec2_deployment`                                        | Provisions EC2-based runners and related scripts                                                          | —                                                                                                          |
| `platform/forge_runners`                                         | Orchestrates both EC2 and ARC runners, including Lambda logic and repo registration                       | —                                                                                                          |
| **integrations**                                                 |                                                                                                           |                                                                                                            |
| `integrations/splunk_cloud_conf_shared`                          | Shared configuration for Splunk Cloud integrations                                                        | —                                                                                                          |
| `integrations/splunk_cloud_data_manager`                         | Integrates with Splunk Cloud for log ingestion and management                                             | Requires S3 bucket (via `storage`), CloudFormation permissions, Splunk tokens in Secrets Manager           |
| `integrations/splunk_cloud_data_manager/data_input`              | Handles Splunk data input integration logic                                                               | —                                                                                                          |
| `integrations/splunk_cloud_data_manager_common`                  | Shared Splunk Cloud Data Manager logic for multi-tenant setups                                            | Same as above                                                                                              |
| `integrations/splunk_o11y_aws_integration`                       | Integrates with Splunk Observability Cloud for metrics and events                                         | Requires CloudFormation permissions, Splunk tokens in Secrets Manager                                       |
| `integrations/splunk_o11y_aws_integration_common`                | Shared Splunk Observability integration logic for multi-tenant setups                                     | Same as above                                                                                              |
| `integrations/teleport`                                          | Integrates Teleport for secure session access and auditing                                                | —                                                                                                          |

---

### 🔑 Integration Notes

- **EKS modules** require the following secrets in AWS Secrets Manager:
  - `/tf/splunk_access_ingest_token`
  - `/tf/splunk_cloud_hec_token_eks`
  - These can be created using the `infra/secrets` module.

- **Splunk Cloud Data Manager** also needs an S3 bucket for CloudFormation templates and data ingestion. Use the `infra/storage` module to provision this bucket.

- **CloudFormation** permissions are required for Splunk and Observability integrations. Use the `infra/cloud_formation` module to grant these permissions.

- **Service Linked Roles**: The `infra/service_linked_roles` module must be applied to allow EC2 Spot instance usage in your AWS account.

---

> **Tip:**  
> Always review the [docs/configurations/secrets.md](docs/configurations/secrets.md) and [docs/configurations/dependency.md](docs/configurations/dependency.md) for more details on required secrets and dependencies.
