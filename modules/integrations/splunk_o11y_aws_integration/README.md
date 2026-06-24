# Splunk Observability AWS Integration Stack

This module deploys the Splunk Observability AWS integration through a CloudFormation stack.

## Why This Module Exists

Forge uses Splunk Observability for AWS metrics while Splunk Cloud handles logs. This module is the regional stack entry point that links AWS metrics into the O11y account.

## What It Manages

- A CloudFormation stack created from the configured template URL.
- Secret lookups for Splunk access material.
- Region, ingest URL, and tagging inputs for the integration.

## Operational Notes

- This module depends on a valid Splunk-provided template URL.
- CloudFormation failures should be debugged in both Terraform output and the CloudFormation events.
- Use the common integration module for IAM role setup when needed.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.47 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.51.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudformation_stack.splunk_integration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack) | resource |
| [aws_secretsmanager_secret.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret_version.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Default AWS region. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_splunk_ingest_url"></a> [splunk\_ingest\_url](#input\_splunk\_ingest\_url) | URL for Splunk Ingest. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_template_url"></a> [template\_url](#input\_template\_url) | URL for the CloudFormation template. | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
