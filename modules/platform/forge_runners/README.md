<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.1 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.7.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.27 |
| <a name="requirement_external"></a> [external](#requirement\_external) | >= 2.3 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.5 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.2 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.13 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.12.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.13.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_arc_runners"></a> [arc\_runners](#module\_arc\_runners) | ../arc_deployment | n/a |
| <a name="module_clean_global_lock_lambda"></a> [clean\_global\_lock\_lambda](#module\_clean\_global\_lock\_lambda) | terraform-aws-modules/lambda/aws | 8.1.0 |
| <a name="module_ec2_runners"></a> [ec2\_runners](#module\_ec2\_runners) | ../ec2_deployment | n/a |
| <a name="module_register_github_app_runner_group_lambda"></a> [register\_github\_app\_runner\_group\_lambda](#module\_register\_github\_app\_runner\_group\_lambda) | terraform-aws-modules/lambda/aws | 8.1.0 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.clean_global_lock_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.register_github_app_runner_group_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.clean_global_lock_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.register_github_app_runner_group_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.clean_global_lock_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.register_github_app_runner_group_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_dynamodb_table.lock_table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_iam_policy.dynamodb_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.ecr_access_for_ec2_instances](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.role_assumption_for_forge_runners](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_lambda_permission.clean_global_lock_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.register_github_app_runner_group_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_secretsmanager_secret.cicd_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.cicd_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_servicecatalogappregistry_application.forge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/servicecatalogappregistry_application) | resource |
| [null_resource.update_github_app_webhook](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.random](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [time_sleep.wait_60_seconds](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_iam_policy_document.clean_global_lock_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.dynamodb_policy_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ecr_access_for_ec2_instances](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.register_github_app_runner_group_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.role_assumption_for_forge_runners](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_secretsmanager_random_password.secret_seeds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_random_password) | data source |
| [aws_secretsmanager_secret.data_cicd_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret_version.data_cicd_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_arc_cluster_name"></a> [arc\_cluster\_name](#input\_arc\_cluster\_name) | Name of the EKS cluster | `string` | n/a | yes |
| <a name="input_arc_runner_specs"></a> [arc\_runner\_specs](#input\_arc\_runner\_specs) | Map of runner specifications | <pre>map(object({<br/>    runner_size = object({<br/>      max_runners = number<br/>      min_runners = number<br/>    })<br/>    scale_set_name               = string<br/>    scale_set_type               = string<br/>    container_actions_runner     = string<br/>    container_limits_cpu         = string<br/>    container_limits_memory      = string<br/>    container_requests_cpu       = string<br/>    container_requests_memory    = string<br/>    volume_requests_storage_size = string<br/>    volume_requests_storage_type = string<br/>  }))</pre> | n/a | yes |
| <a name="input_aws_account_id"></a> [aws\_account\_id](#input\_aws\_account\_id) | AWS account ID (not SL AWS account ID) associated with the infra/backend. | `string` | n/a | yes |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile (i.e. generated via 'sl aws session generate') to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Assuming single region for now. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_deployment_config"></a> [deployment\_config](#input\_deployment\_config) | Prefix for the deployment, used to distinguish resources. | <pre>object({<br/>    prefix        = string<br/>    secret_suffix = string<br/>  })</pre> | n/a | yes |
| <a name="input_ec2_runner_specs"></a> [ec2\_runner\_specs](#input\_ec2\_runner\_specs) | Map of runner specifications | <pre>map(object({<br/>    ami_filter = object({<br/>      name  = list(string)<br/>      state = list(string)<br/>    })<br/>    ami_kms_key_arn = string<br/>    ami_owners      = list(string)<br/>    runner_labels   = list(string)<br/>    extra_labels    = list(string)<br/>    max_instances   = number<br/>    min_run_time    = number<br/>    instance_types  = list(string)<br/>    pool_config = list(object({<br/>      size                         = number<br/>      schedule_expression          = string<br/>      schedule_expression_timezone = string<br/>    }))<br/>    runner_user                   = string<br/>    enable_userdata               = bool<br/>    instance_target_capacity_type = string<br/>    block_device_mappings = list(object({<br/>      delete_on_termination = bool<br/>      device_name           = string<br/>      encrypted             = bool<br/>      iops                  = number<br/>      kms_key_id            = string<br/>      snapshot_id           = string<br/>      throughput            = number<br/>      volume_size           = number<br/>      volume_type           = string<br/>    }))<br/>  }))</pre> | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | Deployment environments. | `string` | n/a | yes |
| <a name="input_ghes_org"></a> [ghes\_org](#input\_ghes\_org) | GitHub organization. | `string` | n/a | yes |
| <a name="input_ghes_url"></a> [ghes\_url](#input\_ghes\_url) | GitHub Enterprise Server URL. | `string` | n/a | yes |
| <a name="input_lambda_subnet_ids"></a> [lambda\_subnet\_ids](#input\_lambda\_subnet\_ids) | So the lambdas can run in our pre-determined subnets. They don't require the same security policy as the runners though. | `list(string)` | n/a | yes |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR) | `string` | n/a | yes |
| <a name="input_logging_retention_in_days"></a> [logging\_retention\_in\_days](#input\_logging\_retention\_in\_days) | Logging retention period in days. | `string` | n/a | yes |
| <a name="input_migrate_arc_cluster"></a> [migrate\_arc\_cluster](#input\_migrate\_arc\_cluster) | Flag to indicate if the cluster is being migrated. | `bool` | `false` | no |
| <a name="input_repository_selection"></a> [repository\_selection](#input\_repository\_selection) | Repository selection type. | `string` | n/a | yes |
| <a name="input_runner_group_name"></a> [runner\_group\_name](#input\_runner\_group\_name) | Name of the group applied to all runners. | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet(s) in which our runners will be deployed. Supplied by the underlying AWS-based CI/CD stack. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_tenant"></a> [tenant](#input\_tenant) | Map of tenant configs | <pre>object({<br/>    name                = string<br/>    iam_roles_to_assume = optional(list(string), [])<br/>    ecr_registries      = optional(list(string), [])<br/>  })</pre> | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC in which our runners will be deployed. Supplied by the underlying AWS-based CI/CD stack. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arc_runners_arn_map"></a> [arc\_runners\_arn\_map](#output\_arc\_runners\_arn\_map) | n/a |
| <a name="output_arc_subnet_cidr_blocks"></a> [arc\_subnet\_cidr\_blocks](#output\_arc\_subnet\_cidr\_blocks) | n/a |
| <a name="output_ec2_runners_ami_name_map"></a> [ec2\_runners\_ami\_name\_map](#output\_ec2\_runners\_ami\_name\_map) | n/a |
| <a name="output_ec2_runners_arn_map"></a> [ec2\_runners\_arn\_map](#output\_ec2\_runners\_arn\_map) | n/a |
| <a name="output_ec2_subnet_cidr_blocks"></a> [ec2\_subnet\_cidr\_blocks](#output\_ec2\_subnet\_cidr\_blocks) | n/a |
| <a name="output_github_app_installation"></a> [github\_app\_installation](#output\_github\_app\_installation) | n/a |
| <a name="output_runner_group_name"></a> [runner\_group\_name](#output\_runner\_group\_name) | n/a |
| <a name="output_tenant"></a> [tenant](#output\_tenant) | n/a |
| <a name="output_webhook_endpoint"></a> [webhook\_endpoint](#output\_webhook\_endpoint) | Needed for the GitHub App to issue callbacks. |
| <a name="output_webhook_secret"></a> [webhook\_secret](#output\_webhook\_secret) | n/a |
<!-- END_TF_DOCS -->
