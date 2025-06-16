<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.90 |
| <a name="requirement_signalfx"></a> [signalfx](#requirement\_signalfx) | 9.9.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.13 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |
| <a name="provider_signalfx"></a> [signalfx](#provider\_signalfx) | 9.9.0 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.13.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.splunk_integration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.splunk_integration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.splunk_managed_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [signalfx_aws_external_integration.integration](https://registry.terraform.io/providers/splunk-terraform/signalfx/9.9.0/docs/resources/aws_external_integration) | resource |
| [signalfx_aws_integration.integration](https://registry.terraform.io/providers/splunk-terraform/signalfx/9.9.0/docs/resources/aws_integration) | resource |
| [time_sleep.wait_30_seconds](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_iam_policy_document.assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.splunk_integration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.splunk_managed_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_secretsmanager_secret.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret_version.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_account_id"></a> [aws\_account\_id](#input\_aws\_account\_id) | AWS account ID (not SL AWS account ID) associated with the infra/backend. | `string` | n/a | yes |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile (i.e., generated via 'sl aws session generate') to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Default AWS region. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_integration_name"></a> [integration\_name](#input\_integration\_name) | Name of the integration. | `string` | n/a | yes |
| <a name="input_integration_regions"></a> [integration\_regions](#input\_integration\_regions) | List of regions for the integration. | `list(string)` | n/a | yes |
| <a name="input_splunk_api_url"></a> [splunk\_api\_url](#input\_splunk\_api\_url) | URL for plunk Observability Cloud API. | `string` | n/a | yes |
| <a name="input_splunk_organization_id"></a> [splunk\_organization\_id](#input\_splunk\_organization\_id) | organization ID for Splunk Observability Cloud. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_iam_role_splunk_integration"></a> [iam\_role\_splunk\_integration](#output\_iam\_role\_splunk\_integration) | n/a |
<!-- END_TF_DOCS -->
