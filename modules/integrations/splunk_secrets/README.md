<!-- BEGIN_TF_DOCS -->

## Requirements

| Name                                                                     | Version  |
| ------------------------------------------------------------------------ | -------- |
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | >= 1.9.1 |
| <a name="requirement_aws"></a> [aws](#requirement_aws)                   | ~> 5.90  |
| <a name="requirement_time"></a> [time](#requirement_time)                | ~> 0.13  |

## Providers

| Name                                                | Version |
| --------------------------------------------------- | ------- |
| <a name="provider_aws"></a> [aws](#provider_aws)    | 5.99.1  |
| <a name="provider_time"></a> [time](#provider_time) | 0.13.1  |

## Modules

No modules.

## Resources

| Name                                                                                                                                                             | Type        |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| [aws_secretsmanager_secret.cicd_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret)                      | resource    |
| [aws_secretsmanager_secret_version.cicd_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version)      | resource    |
| [time_sleep.wait_30_seconds](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep)                                                 | resource    |
| [aws_secretsmanager_random_password.secret_seeds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_random_password) | data source |

## Inputs

| Name                                                                  | Description                          | Type          | Default | Required |
| --------------------------------------------------------------------- | ------------------------------------ | ------------- | ------- | :------: |
| <a name="input_aws_profile"></a> [aws_profile](#input_aws_profile)    | AWS profile to use.                  | `string`      | n/a     |   yes    |
| <a name="input_aws_region"></a> [aws_region](#input_aws_region)       | Default AWS region.                  | `string`      | n/a     |   yes    |
| <a name="input_default_tags"></a> [default_tags](#input_default_tags) | A map of tags to apply to resources. | `map(string)` | n/a     |   yes    |
| <a name="input_tags"></a> [tags](#input_tags)                         | A map of tags to apply to resources. | `map(string)` | n/a     |   yes    |

## Outputs

No outputs.

<!-- END_TF_DOCS -->
