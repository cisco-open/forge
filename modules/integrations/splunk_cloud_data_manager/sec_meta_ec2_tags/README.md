<!-- BEGIN_TF_DOCS -->

## Requirements

| Name                                                                     | Version  |
| ------------------------------------------------------------------------ | -------- |
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | >= 1.9.1 |
| <a name="requirement_aws"></a> [aws](#requirement_aws)                   | ~> 5.90  |
| <a name="requirement_external"></a> [external](#requirement_external)    | ~> 2.3   |
| <a name="requirement_local"></a> [local](#requirement_local)             | 2.5.2    |
| <a name="requirement_null"></a> [null](#requirement_null)                | ~> 3.2   |
| <a name="requirement_random"></a> [random](#requirement_random)          | 3.7.1    |
| <a name="requirement_time"></a> [time](#requirement_time)                | ~> 0.13  |

## Providers

| Name                                                            | Version |
| --------------------------------------------------------------- | ------- |
| <a name="provider_aws"></a> [aws](#provider_aws)                | ~> 5.90 |
| <a name="provider_external"></a> [external](#provider_external) | ~> 2.3  |
| <a name="provider_null"></a> [null](#provider_null)             | ~> 3.2  |
| <a name="provider_random"></a> [random](#provider_random)       | 3.7.1   |

## Modules

No modules.

## Resources

| Name                                                                                                                                                      | Type        |
| --------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| [aws_s3_object.cloudformation_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object)                            | resource    |
| [null_resource.create_integration](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource)                                 | resource    |
| [null_resource.delete_integration](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource)                                 | resource    |
| [random_uuid.splunk_input_uuid](https://registry.terraform.io/providers/hashicorp/random/3.7.1/docs/resources/uuid)                                       | resource    |
| [aws_secretsmanager_secret.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret)                 | data source |
| [aws_secretsmanager_secret_version.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |
| [external_external.ensure_template_file](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external)                    | data source |
| [external_external.splunk_dm_version](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external)                       | data source |

## Inputs

| Name                                                                                                      | Description                             | Type                                                               | Default | Required |
| --------------------------------------------------------------------------------------------------------- | --------------------------------------- | ------------------------------------------------------------------ | ------- | :------: |
| <a name="input_cloudformation_s3_config"></a> [cloudformation_s3_config](#input_cloudformation_s3_config) | S3 bucket for CloudFormation templates. | <pre>object({<br/> bucket = string<br/> key = string<br/> })</pre> | n/a     |   yes    |
| <a name="input_splunk_cloud"></a> [splunk_cloud](#input_splunk_cloud)                                     | Splunk Cloud endpoint.                  | `string`                                                           | n/a     |   yes    |
| <a name="input_splunk_cloud_input_json"></a> [splunk_cloud_input_json](#input_splunk_cloud_input_json)    | Splunk Cloud input JSON.                | `string`                                                           | n/a     |   yes    |
| <a name="input_tags"></a> [tags](#input_tags)                                                             | Tags to apply to resources.             | `map(string)`                                                      | n/a     |   yes    |
| <a name="input_tags_all"></a> [tags_all](#input_tags_all)                                                 | All Tags to apply to resources.         | `map(string)`                                                      | n/a     |   yes    |

## Outputs

| Name                                                                                                                             | Description                                                                                |
| -------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| <a name="output_splunk_integration_name"></a> [splunk_integration_name](#output_splunk_integration_name)                         | The name of the Splunk integration CloudFormation stack.                                   |
| <a name="output_splunk_integration_tags"></a> [splunk_integration_tags](#output_splunk_integration_tags)                         | The tags applied to the Splunk integration CloudFormation stack.                           |
| <a name="output_splunk_integration_tags_all"></a> [splunk_integration_tags_all](#output_splunk_integration_tags_all)             | All tags applied to the Splunk integration CloudFormation stack, including inherited tags. |
| <a name="output_splunk_integration_template_url"></a> [splunk_integration_template_url](#output_splunk_integration_template_url) | The URL of the CloudFormation template for the Splunk integration.                         |

<!-- END_TF_DOCS -->
