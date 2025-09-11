<!-- BEGIN_TF_DOCS -->

## Requirements

| Name                                                                     | Version  |
| ------------------------------------------------------------------------ | -------- |
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | >= 1.9.1 |
| <a name="requirement_aws"></a> [aws](#requirement_aws)                   | ~> 5.90  |

## Providers

| Name                                             | Version |
| ------------------------------------------------ | ------- |
| <a name="provider_aws"></a> [aws](#provider_aws) | 5.98.0  |

## Modules

No modules.

## Resources

| Name                                                                                                                                                           | Type        |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| [aws_ecr_repository_policy.repository_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository_policy)               | resource    |
| [aws_iam_role.role_for_forge_runners](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                    | resource    |
| [aws_iam_role_policy.packer_support_for_forge_runners](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy)            | resource    |
| [aws_iam_role_policy.s3_access_for_forge_runners](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy)                 | resource    |
| [aws_iam_role_policy.secrets_access_for_forge_runners](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy)            | resource    |
| [aws_iam_policy_document.assume_role_for_forge_runners](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)    | data source |
| [aws_iam_policy_document.ecr_repository_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)            | data source |
| [aws_iam_policy_document.packer_support_for_forge_runners](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.s3_access_for_forge_runners](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)      | data source |
| [aws_iam_policy_document.secrets_access_for_forge_runners](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name                                                                  | Description                          | Type                                                                                                                                                                       | Default | Required |
| --------------------------------------------------------------------- | ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | :------: |
| <a name="input_aws_profile"></a> [aws_profile](#input_aws_profile)    | AWS profile to use.                  | `string`                                                                                                                                                                   | n/a     |   yes    |
| <a name="input_aws_region"></a> [aws_region](#input_aws_region)       | Default AWS region.                  | `string`                                                                                                                                                                   | n/a     |   yes    |
| <a name="input_default_tags"></a> [default_tags](#input_default_tags) | A map of tags to apply to resources. | `map(string)`                                                                                                                                                              | n/a     |   yes    |
| <a name="input_forge"></a> [forge](#input_forge)                      | Configuration for Forge runners.     | <pre>object({<br/> runner_roles = list(string)<br/> ecr_repositories = object({<br/> names = list(string)<br/> ecr_access_account_ids = list(string)<br/> })<br/> })</pre> | n/a     |   yes    |
| <a name="input_tags"></a> [tags](#input_tags)                         | A map of tags to apply to resources. | `map(string)`                                                                                                                                                              | n/a     |   yes    |

## Outputs

No outputs.

<!-- END_TF_DOCS -->
