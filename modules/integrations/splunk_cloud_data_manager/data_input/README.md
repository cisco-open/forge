<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.90 |
| <a name="requirement_external"></a> [external](#requirement\_external) | ~> 2.3 |
| <a name="requirement_local"></a> [local](#requirement\_local) | 2.5.2 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.2 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.7.1 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.13 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.90 |
| <a name="provider_external"></a> [external](#provider\_external) | ~> 2.3 |
| <a name="provider_null"></a> [null](#provider\_null) | ~> 3.2 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_s3_object.cloudformation_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [null_resource.create_integration](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.delete_integration](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_uuid.splunk_input_uuid](https://registry.terraform.io/providers/hashicorp/random/3.7.1/docs/resources/uuid) | resource |
| [aws_secretsmanager_secret.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret_version.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |
| [external_external.ensure_template_file](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |
| [external_external.splunk_dm_version](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudformation_s3_config"></a> [cloudformation\_s3\_config](#input\_cloudformation\_s3\_config) | S3 bucket for CloudFormation templates. | <pre>object({<br/>    bucket = string<br/>    key    = string<br/>  })</pre> | n/a | yes |
| <a name="input_splunk_cloud"></a> [splunk\_cloud](#input\_splunk\_cloud) | Splunk Cloud endpoint. | `string` | n/a | yes |
| <a name="input_splunk_cloud_input_json"></a> [splunk\_cloud\_input\_json](#input\_splunk\_cloud\_input\_json) | Splunk Cloud input JSON. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_tags_all"></a> [tags\_all](#input\_tags\_all) | All Tags to apply to resources. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_splunk_integration_name"></a> [splunk\_integration\_name](#output\_splunk\_integration\_name) | The name of the Splunk integration CloudFormation stack. |
| <a name="output_splunk_integration_tags"></a> [splunk\_integration\_tags](#output\_splunk\_integration\_tags) | The tags applied to the Splunk integration CloudFormation stack. |
| <a name="output_splunk_integration_tags_all"></a> [splunk\_integration\_tags\_all](#output\_splunk\_integration\_tags\_all) | All tags applied to the Splunk integration CloudFormation stack, including inherited tags. |
| <a name="output_splunk_integration_template_url"></a> [splunk\_integration\_template\_url](#output\_splunk\_integration\_template\_url) | The URL of the CloudFormation template for the Splunk integration. |
<!-- END_TF_DOCS -->
