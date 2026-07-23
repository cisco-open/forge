# Forge Runners Tenant Stack

This is the umbrella tenant module for Forge GitHub Actions runners.

## Why This Module Exists

Forge is a multi-tenant CI platform built around ephemeral runners, short-lived identity, and centralized operations. This module composes the tenant stack: EC2 runners, ARC runners, GitHub App settings, runner group reconciliation, trust validation, log archival, webhook relay, and self-healing support utilities.

## What It Manages

- EC2 runner deployment and ARC runner deployment.
- GitHub App secret material in SSM Parameter Store.
- IAM policies that let runners assume tenant-approved roles and pull allowed ECR images.
- Runner group registration, trust validation, global lock, job log archival, webhook relay, and DLQ redrive helpers.
- AppRegistry application metadata for the tenant deployment.

## Operational Notes

- This is the best starting point when onboarding or debugging a tenant because it shows how the platform pieces compose.
- The tenant `deployment_config` defines the GitHub App, runner group, repository selection, and IAM bridge.
- The EC2 and ARC lanes can both be enabled for the same tenant; workflows choose by labels.
- Changing GitHub App or runner-group settings can affect job routing immediately.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.7.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.47 |
| <a name="requirement_external"></a> [external](#requirement\_external) | >= 2.3 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.5 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.2 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.13 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.51.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.3.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.0 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.14.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
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
| ---- | ---- |
| [aws_iam_policy.ecr_access_for_ec2_instances](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.role_assumption_for_forge_runners](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_servicecatalogappregistry_application.forge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/servicecatalogappregistry_application) | resource |
| [aws_ssm_parameter.github_app_client_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.github_app_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.github_app_installation_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.github_app_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.github_app_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.github_app_webhook_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [null_resource.update_github_app_webhook](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.random](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_password.github_app_webhook_secret](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [time_rotating.every_30_days](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/rotating) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.ecr_access_for_ec2_instances](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.role_assumption_for_forge_runners](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.github_app_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_arc_deployment_specs"></a> [arc\_deployment\_specs](#input\_arc\_deployment\_specs) | Deployment configuration for Azure Container Apps (ARC) runners.<br/><br/>Top-level fields:<br/>  - cluster\_name   : Name of the EKS cluster used for ARC runners.<br/>  - migrate\_cluster: Optional flag to indicate a one-time migration or<br/>    blue/green cutover of the ARC runner cluster.<br/>  - runner\_specs   : Map of ARC runner pool keys to their sizing and<br/>    container resource settings.<br/><br/>runner\_specs[*] object fields:<br/>  - runner\_size.max\_runners: Maximum concurrent ARC runners for this pool.<br/>  - runner\_size.min\_runners: Minimum number of warm runners.<br/>  - scale\_set\_name         : Logical name for the scale set / pool.<br/>  - scale\_set\_type         : Backing type for the scale set (for example,<br/>    kubernetes or containerapp, depending on integration).<br/>  - scale\_set\_labels       : GitHub runner labels advertised by this ARC<br/>    scale set.<br/>  - container\_images            : Container images used by the ARC runner,<br/>                                  sidecars, and DinD containers.<br/>  - container\_limits\_cpu        : CPU limit for the runner container.<br/>  - container\_limits\_memory     : Memory limit for the runner container.<br/>  - container\_requests\_cpu      : CPU request (baseline reservation).<br/>  - container\_requests\_memory   : Memory request (baseline reservation).<br/>  - volume\_requests\_storage\_size: Size of attached storage for the runner.<br/>  - volume\_requests\_storage\_type: Storage class or type for attached volume. | <pre>object({<br/>    cluster_name    = string<br/>    migrate_cluster = optional(bool, false)<br/>    runner_specs = map(object({<br/>      runner_size = object({<br/>        max_runners = number<br/>        min_runners = number<br/>      })<br/>      scale_set_name   = string<br/>      scale_set_type   = string<br/>      scale_set_labels = list(string)<br/>      container_images = optional(object({<br/>        actions_runner = optional(string, "ghcr.io/actions/actions-runner:latest")<br/>        busybox        = optional(string, "public.ecr.aws/docker/library/busybox:stable")<br/>        dind_rootless  = optional(string, "public.ecr.aws/docker/library/docker:dind-rootless")<br/>      }), {})<br/>      container_limits_cpu         = string<br/>      container_limits_memory      = string<br/>      container_requests_cpu       = string<br/>      container_requests_memory    = string<br/>      volume_requests_storage_size = string<br/>      volume_requests_storage_type = string<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region where Forge runners and supporting infrastructure are deployed. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_deployment_config"></a> [deployment\_config](#input\_deployment\_config) | High-level deployment configuration for a Forge runner installation.<br/><br/>Top-level fields:<br/>  - deployment\_prefix: Prefix used when naming resources (for example,<br/>    log groups, KMS keys, and SSM parameters).<br/>  - env              : Logical environment name (for example, dev, stage,<br/>    prod). Used for tagging and dashboards.<br/><br/>github\_app object:<br/>  - id             : Numeric GitHub App ID.<br/>  - client\_id      : OAuth client ID for the app.<br/>  - installation\_id: GitHub App installation ID for this tenant.<br/>  - name           : GitHub App name, used to build URLs and logs.<br/><br/>github object:<br/>  - ghes\_org            : GitHub organization that owns the repos where<br/>    runners will be used.<br/>  - ghes\_url            : GitHub.com or GHES base URL. Empty string implies<br/>    public github.com.<br/>  - repository\_selection: Scope for runners (all or selected repositories).<br/>  - runner\_group\_name   : GitHub runner group to attach new runners to.<br/><br/>tenant object:<br/>  - name                        : Tenant identifier used in naming and<br/>    tagging.<br/>  - iam\_roles\_to\_assume         : Optional list of IAM role ARNs that<br/>    runners are allowed to assume for workload execution.<br/>  - ecr\_registries              : Optional list of ECR registry URLs that<br/>    runners may need to pull images from.<br/>  - github\_logs\_reader\_role\_arns: Optional list of IAM roles that can read<br/>    GitHub Actions logs for this tenant. | <pre>object({<br/>    deployment_prefix = string<br/>    secret_suffix     = string<br/>    env               = string<br/>    github_app = object({<br/>      id              = string<br/>      client_id       = string<br/>      installation_id = string<br/>      name            = string<br/>    })<br/>    github = object({<br/>      ghes_org             = string<br/>      ghes_url             = string<br/>      repository_selection = string<br/>      runner_group_name    = string<br/>    })<br/>    tenant = object({<br/>      name                         = string<br/>      iam_roles_to_assume          = optional(list(string), [])<br/>      ecr_registries               = optional(list(string), [])<br/>      github_logs_reader_role_arns = optional(list(string), [])<br/>    })<br/>  })</pre> | n/a | yes |
| <a name="input_ec2_deployment_specs"></a> [ec2\_deployment\_specs](#input\_ec2\_deployment\_specs) | EC2 deployment configuration for GitHub Actions runners.<br/><br/>Top-level fields:<br/>  - lambda\_subnet\_ids: Subnets where runner-related lambdas execute.<br/>    These can be more permissive than the runner subnets.<br/>  - subnet\_ids       : Subnets where the EC2 runners are launched.<br/>  - vpc\_id           : VPC that contains both runner and lambda subnets.<br/>  - runner\_specs     : Map of runner pool keys to their EC2 sizing and<br/>                       scheduling configuration.<br/><br/>runner\_specs[*] object fields:<br/>  - ami\_filter      : Name/state filters used to select the runner AMI.<br/>  - ami\_kms\_key\_arn : KMS key ARN used to encrypt AMI EBS volumes.<br/>  - ami\_owners      : List of AWS account IDs that own the AMI.<br/>  - runner\_labels   : Base GitHub labels applied to jobs for this pool.<br/>  - runner\_os       : Runner operating system (for example, linux).<br/>  - runner\_architecture: CPU architecture (for example, x86\_64 or arm64).<br/>  - extra\_labels    : Additional GitHub labels that further specialize<br/>                      this runner pool.<br/>  - enable\_dynamic\_labels: Enables dynamic `ghr-` labels for this runner<br/>                      pool.<br/>  - ec2\_dynamic\_labels\_policy: Optional policy for `ghr-ec2-*` labels for<br/>                      this runner pool.<br/>  - lambda\_event\_source\_mapping\_batch\_size: Optional maximum number of queued<br/>                      jobs passed to the scale-up Lambda per invocation.<br/>  - lambda\_event\_source\_mapping\_maximum\_batching\_window\_in\_seconds: Optional<br/>                      maximum time to collect queued jobs before invoking the<br/>                      scale-up Lambda.<br/>  - max\_instances   : Maximum number of EC2 runners in this pool.<br/>  - min\_run\_time    : Minimum job run time (in minutes) before a runner<br/>                      is eligible for scale-down.<br/>  - instance\_types  : Allowed EC2 instance types for runners in this pool.<br/>  - placement       : Optional EC2 placement configuration for the runner<br/>                      launch template.<br/>  - license\_specifications: Optional EC2 License Manager configuration ARNs.<br/>  - use\_dedicated\_host: Whether this runner pool should use EC2 dedicated<br/>                      hosts.<br/>  - pool\_config     : List of pool size schedules (size + cron expression<br/>                      and optional time zone) controlling baseline capacity.<br/>  - runner\_user     : OS user under which the GitHub runner process runs.<br/>  - enable\_userdata : Whether the module should inject its standard<br/>                      userdata to configure the runner VM.<br/>  - instance\_target\_capacity\_type: EC2 capacity type to use (spot or<br/>                      on-demand).<br/>  - block\_device\_mappings: EBS volume configuration for the runner<br/>                      instances, including size, type, encryption, and KMS. | <pre>object({<br/>    lambda_subnet_ids = list(string)<br/>    subnet_ids        = list(string)<br/>    lambda_vpc_id     = string<br/>    vpc_id            = string<br/>    scale_errors      = optional(list(string), [])<br/>    runner_specs = map(object({<br/>      ami_filter = object({<br/>        name  = list(string)<br/>        state = list(string)<br/>      })<br/>      ami_kms_key_arn                                                = string<br/>      ami_owners                                                     = list(string)<br/>      runner_labels                                                  = list(string)<br/>      runner_os                                                      = string<br/>      runner_architecture                                            = string<br/>      extra_labels                                                   = list(string)<br/>      enable_dynamic_labels                                          = optional(bool, false)<br/>      ec2_dynamic_labels_policy                                      = optional(any, null)<br/>      lambda_event_source_mapping_batch_size                         = optional(number, 10)<br/>      lambda_event_source_mapping_maximum_batching_window_in_seconds = optional(number, 0)<br/>      max_instances                                                  = number<br/>      min_run_time                                                   = number<br/>      instance_types                                                 = list(string)<br/>      license_specifications = optional(list(object({<br/>        license_configuration_arn = string<br/>      })), null)<br/>      placement = optional(object({<br/>        affinity                = optional(string)<br/>        availability_zone       = optional(string)<br/>        group_id                = optional(string)<br/>        group_name              = optional(string)<br/>        host_id                 = optional(string)<br/>        host_resource_group_arn = optional(string)<br/>        spread_domain           = optional(string)<br/>        tenancy                 = optional(string)<br/>        partition_number        = optional(number)<br/>      }), null)<br/>      use_dedicated_host = optional(bool, false)<br/>      pool_config = list(object({<br/>        size                         = number<br/>        schedule_expression          = string<br/>        schedule_expression_timezone = string<br/>      }))<br/>      runner_user                   = string<br/>      enable_userdata               = bool<br/>      instance_target_capacity_type = string<br/>      vpc_id                        = optional(string, null)<br/>      subnet_ids                    = optional(list(string), null)<br/>      block_device_mappings = list(object({<br/>        delete_on_termination = bool<br/>        device_name           = string<br/>        encrypted             = bool<br/>        iops                  = number<br/>        kms_key_id            = string<br/>        snapshot_id           = string<br/>        throughput            = number<br/>        volume_size           = number<br/>        volume_type           = string<br/>      }))<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_github_webhook_relay"></a> [github\_webhook\_relay](#input\_github\_webhook\_relay) | Configuration for the (optional) webhook relay source module.<br/>If enabled=true we provision the API Gateway + source EventBridge forwarding rule.<br/>destination\_event\_bus\_name must already exist or be created in the destination account (or via the destination submodule run there). | <pre>object({<br/>    enabled                     = bool<br/>    destination_account_id      = optional(string)<br/>    destination_event_bus_name  = optional(string)<br/>    destination_region          = optional(string)<br/>    destination_reader_role_arn = optional(string)<br/>  })</pre> | <pre>{<br/>  "destination_account_id": "",<br/>  "destination_event_bus_name": "",<br/>  "destination_reader_role_arn": "",<br/>  "destination_region": "",<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR) | `string` | n/a | yes |
| <a name="input_logging_retention_in_days"></a> [logging\_retention\_in\_days](#input\_logging\_retention\_in\_days) | Logging retention period in days. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_forge_core"></a> [forge\_core](#output\_forge\_core) | Core tenant-level metadata (non-sensitive). |
| <a name="output_forge_github_actions_job_logs"></a> [forge\_github\_actions\_job\_logs](#output\_forge\_github\_actions\_job\_logs) | GitHub Actions job log archival resources. |
| <a name="output_forge_github_app"></a> [forge\_github\_app](#output\_forge\_github\_app) | GitHub App related outputs. |
| <a name="output_forge_runners"></a> [forge\_runners](#output\_forge\_runners) | Combined runners output (EC2 + ARC) |
| <a name="output_forge_webhook_relay"></a> [forge\_webhook\_relay](#output\_forge\_webhook\_relay) | Webhook relay integration outputs. |
<!-- END_TF_DOCS -->
