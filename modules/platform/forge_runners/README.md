<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.7.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.25 |
| <a name="requirement_external"></a> [external](#requirement\_external) | >= 2.3 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.5 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.2 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.13 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.25.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.13.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_arc_runners"></a> [arc\_runners](#module\_arc\_runners) | ../arc_deployment | n/a |
| <a name="module_ec2_runners"></a> [ec2\_runners](#module\_ec2\_runners) | ../ec2_deployment | n/a |
| <a name="module_forge_trust_validator"></a> [forge\_trust\_validator](#module\_forge\_trust\_validator) | ./forge_trust_validator | n/a |
| <a name="module_github_actions_job_logs"></a> [github\_actions\_job\_logs](#module\_github\_actions\_job\_logs) | ./github_actions_job_logs | n/a |
| <a name="module_github_app_runner_group"></a> [github\_app\_runner\_group](#module\_github\_app\_runner\_group) | ./github_app_runner_group | n/a |
| <a name="module_github_global_lock"></a> [github\_global\_lock](#module\_github\_global\_lock) | ./github_global_lock | n/a |
| <a name="module_github_webhook_relay"></a> [github\_webhook\_relay](#module\_github\_webhook\_relay) | ./github_webhook_relay | n/a |
| <a name="module_redrive_deadletter"></a> [redrive\_deadletter](#module\_redrive\_deadletter) | ./redrive_deadletter | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.ecr_access_for_ec2_instances](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.role_assumption_for_forge_runners](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_secretsmanager_secret.cicd_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.cicd_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_servicecatalogappregistry_application.forge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/servicecatalogappregistry_application) | resource |
| [null_resource.update_github_app_webhook](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.random](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [time_sleep.wait_60_seconds](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.ecr_access_for_ec2_instances](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.role_assumption_for_forge_runners](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
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
| <a name="input_ec2_runner_specs"></a> [ec2\_runner\_specs](#input\_ec2\_runner\_specs) | Map of runner specifications | <pre>map(object({<br/>    ami_filter = object({<br/>      name  = list(string)<br/>      state = list(string)<br/>    })<br/>    ami_kms_key_arn     = string<br/>    ami_owners          = list(string)<br/>    runner_labels       = list(string)<br/>    runner_os           = string<br/>    runner_architecture = string<br/>    extra_labels        = list(string)<br/>    max_instances       = number<br/>    min_run_time        = number<br/>    instance_types      = list(string)<br/>    pool_config = list(object({<br/>      size                         = number<br/>      schedule_expression          = string<br/>      schedule_expression_timezone = string<br/>    }))<br/>    runner_user                   = string<br/>    enable_userdata               = bool<br/>    instance_target_capacity_type = string<br/>    block_device_mappings = list(object({<br/>      delete_on_termination = bool<br/>      device_name           = string<br/>      encrypted             = bool<br/>      iops                  = number<br/>      kms_key_id            = string<br/>      snapshot_id           = string<br/>      throughput            = number<br/>      volume_size           = number<br/>      volume_type           = string<br/>    }))<br/>  }))</pre> | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | Deployment environments. | `string` | n/a | yes |
| <a name="input_ghes_org"></a> [ghes\_org](#input\_ghes\_org) | GitHub organization. | `string` | n/a | yes |
| <a name="input_ghes_url"></a> [ghes\_url](#input\_ghes\_url) | GitHub Enterprise Server URL. | `string` | n/a | yes |
| <a name="input_github_webhook_relay"></a> [github\_webhook\_relay](#input\_github\_webhook\_relay) | Configuration for the (optional) webhook relay source module.<br/>If enabled=true we provision the API Gateway + source EventBridge forwarding rule.<br/>destination\_event\_bus\_name must already exist or be created in the destination account (or via the destination submodule run there). | <pre>object({<br/>    enabled                     = bool<br/>    destination_account_id      = optional(string)<br/>    destination_event_bus_name  = optional(string)<br/>    destination_region          = optional(string)<br/>    destination_reader_role_arn = optional(string)<br/>  })</pre> | <pre>{<br/>  "destination_account_id": "",<br/>  "destination_event_bus_name": "",<br/>  "destination_reader_role_arn": "",<br/>  "destination_region": "",<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_lambda_subnet_ids"></a> [lambda\_subnet\_ids](#input\_lambda\_subnet\_ids) | So the lambdas can run in our pre-determined subnets. They don't require the same security policy as the runners though. | `list(string)` | n/a | yes |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR) | `string` | n/a | yes |
| <a name="input_logging_retention_in_days"></a> [logging\_retention\_in\_days](#input\_logging\_retention\_in\_days) | Logging retention period in days. | `string` | n/a | yes |
| <a name="input_migrate_arc_cluster"></a> [migrate\_arc\_cluster](#input\_migrate\_arc\_cluster) | Flag to indicate if the cluster is being migrated. | `bool` | `false` | no |
| <a name="input_repository_selection"></a> [repository\_selection](#input\_repository\_selection) | Repository selection type. | `string` | n/a | yes |
| <a name="input_runner_group_name"></a> [runner\_group\_name](#input\_runner\_group\_name) | Name of the group applied to all runners. | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet(s) in which our runners will be deployed. Supplied by the underlying AWS-based CI/CD stack. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_tenant"></a> [tenant](#input\_tenant) | Map of tenant configs | <pre>object({<br/>    name                         = string<br/>    iam_roles_to_assume          = optional(list(string), [])<br/>    ecr_registries               = optional(list(string), [])<br/>    github_logs_reader_role_arns = optional(list(string), [])<br/>  })</pre> | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC in which our runners will be deployed. Supplied by the underlying AWS-based CI/CD stack. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_forge_core"></a> [forge\_core](#output\_forge\_core) | Core tenant-level metadata (non-sensitive). |
| <a name="output_forge_github_actions_job_logs"></a> [forge\_github\_actions\_job\_logs](#output\_forge\_github\_actions\_job\_logs) | GitHub Actions job log archival resources. |
| <a name="output_forge_github_app"></a> [forge\_github\_app](#output\_forge\_github\_app) | GitHub App related outputs. |
| <a name="output_forge_runners"></a> [forge\_runners](#output\_forge\_runners) | Combined runners output (EC2 + ARC) |
| <a name="output_forge_webhook_relay"></a> [forge\_webhook\_relay](#output\_forge\_webhook\_relay) | Webhook relay integration outputs. |
<!-- END_TF_DOCS -->
