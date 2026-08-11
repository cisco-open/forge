# EC2 Runner Deployment

This module deploys Forge EC2 runner pools through the upstream
`terraform-aws-github-runner` multi-runner module.

## Why This Module Exists

The nested, v2-compatible EC2 input lets each runner lane configure the
upstream EC2 provider object while sharing Forge's webhook and runner control
plane. Forge currently translates that input to the released v1
`multi_runner_config`, so this phase does not enable upstream's experimental v2
runtime. EC2 supports custom AMIs, macOS/Windows, dedicated hosts, and larger
hardware profiles.

## What It Manages

- The upstream multi-runner control plane for webhook, scale-up, scale-down, and ephemeral runner registration.
- Per-lane label matching, warm pool schedules, and capacity limits.
- EC2 AMI, instance type, storage, user data, tag, and logging-hook configuration.
- Shared KMS key material, Lambda egress security group, and EC2 AMI and tag helpers.

## Operational Notes

- This is a breaking input migration: every `runner_specs` entry must contain
  `compute_provider.ec2`. The legacy flat EC2 shape is not accepted.
- The EC2 block mirrors the upstream v2 nested contract and is adapted to the
  stable upstream v1 fields. Forge still owns AMI
  refresh and runner instance profiles, so EC2 lanes require a non-null,
  module-managed `ami` block and cannot select `ami.id_ssm_parameter` or an
  external `instance_profile`. The scheduled refresh uses the same default AMI
  name filter as the upstream EC2 provider for each runner OS and architecture;
  values in `ami.filter` override those defaults.
- Stable v1 has no per-lane user-data debug flag, so
  `user_data.debug_logging_enabled` must remain `false` during this adapter
  phase.
- Every EC2 runner is ephemeral and is expected to register for one job and then be reaped.
- Label sets are the API contract with tenant workflows, so exact matching matters.
- Use warm pools only where startup latency justifies the idle cost.
- Subnet IP capacity and EC2 capacity errors are expected operational signals, not unusual exceptions.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.7.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.47 |
| <a name="requirement_external"></a> [external](#requirement\_external) | >= 2.3 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.58.0 |
| <a name="provider_external"></a> [external](#provider\_external) | 2.4.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_ec2_update_runner_ssm_ami"></a> [ec2\_update\_runner\_ssm\_ami](#module\_ec2\_update\_runner\_ssm\_ami) | ./ec2_update_runner_ssm_ami | n/a |
| <a name="module_ec2_update_runner_tags"></a> [ec2\_update\_runner\_tags](#module\_ec2\_update\_runner\_tags) | ./ec2_update_runner_tags | n/a |
| <a name="module_runners"></a> [runners](#module\_runners) | git::https://github.com/github-aws-runners/terraform-aws-github-runner.git//modules/multi-runner | v7.10.1 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.webhook_api_gateway_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_policy.ec2_tags](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.runner_hooks_ssm_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_kms_alias.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_security_group.gh_runner_lambda_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_parameter.hook_job_completed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.hook_job_started](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ami.runner_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.ec2_tags](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.runner_hooks_ssm_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_ssm_parameter.ami_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_subnet.runner_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [external_external.download_lambdas](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Assuming single region for now. | `string` | n/a | yes |
| <a name="input_network_configs"></a> [network\_configs](#input\_network\_configs) | n/a | <pre>object({<br/>    vpc_id            = string<br/>    subnet_ids        = list(string)<br/>    lambda_vpc_id     = string<br/>    lambda_subnet_ids = list(string)<br/>  })</pre> | n/a | yes |
| <a name="input_runner_configs"></a> [runner\_configs](#input\_runner\_configs) | n/a | <pre>object({<br/>    env                       = string<br/>    prefix                    = string<br/>    ghes_url                  = string<br/>    ghes_org                  = string<br/>    log_level                 = string<br/>    logging_retention_in_days = string<br/>    github_app = object({<br/>      key_base64     = string<br/>      id             = string<br/>      webhook_secret = string<br/>    })<br/>    runner_iam_role_managed_policy_arns = list(string)<br/>    runner_group_name                   = string<br/>    runner_specs = map(object({<br/>      runner_labels         = list(string)<br/>      runner_os             = string<br/>      runner_architecture   = string<br/>      extra_labels          = list(string)<br/>      enable_dynamic_labels = optional(bool, false)<br/>      aws_dynamic_labels_policy = optional(object({<br/>        blocked_keys = optional(list(string), [])<br/>        restricted_keys = optional(map(object({<br/>          allowed = optional(list(string), [])<br/>          denied  = optional(list(string), [])<br/>          max     = optional(string, null)<br/>        })), {})<br/>      }), null)<br/>      lambda_event_source_mapping_batch_size                         = optional(number, 10)<br/>      lambda_event_source_mapping_maximum_batching_window_in_seconds = optional(number, 0)<br/>      redrive_build_queue = optional(object({<br/>        enabled         = optional(bool, true)<br/>        maxReceiveCount = optional(number, 10)<br/>      }), {})<br/>      max_instances = number<br/>      min_run_time  = number<br/>      pool_config = list(object({<br/>        size                         = number<br/>        schedule_expression          = string<br/>        schedule_expression_timezone = string<br/>      }))<br/>      runner_user = string<br/>      compute_provider = object({<br/>        ec2 = object({<br/>          metadata_options = optional(object({<br/>            instance_metadata_tags      = optional(string, "enabled")<br/>            http_endpoint               = optional(string, "enabled")<br/>            http_tokens                 = optional(string, "required")<br/>            http_put_response_hop_limit = optional(number, 1)<br/>          }), {})<br/>          ami = optional(object({<br/>            filter = optional(map(list(string)), { state = ["available"] })<br/>            owners = optional(list(string), ["amazon"])<br/>            id_ssm_parameter = optional(object({<br/>              arn = string<br/>            }), null)<br/>            kms_key = optional(object({<br/>              arn = string<br/>            }), null)<br/>          }), null)<br/>          block_device_mappings = optional(list(object({<br/>            delete_on_termination      = optional(bool, true)<br/>            device_name                = optional(string, "/dev/xvda")<br/>            encrypted                  = optional(bool, true)<br/>            iops                       = optional(number)<br/>            kms_key_id                 = optional(string)<br/>            snapshot_id                = optional(string)<br/>            throughput                 = optional(number)<br/>            volume_initialization_rate = optional(number)<br/>            volume_size                = number<br/>            volume_type                = optional(string, "gp3")<br/>            })), [{<br/>            volume_size = 30<br/>          }])<br/>          create_service_linked_role_spot = optional(bool, false)<br/>          credit_specification            = optional(string, null)<br/>          ebs_optimized                   = optional(bool, false)<br/>          cloudwatch_agent = optional(object({<br/>            enabled = optional(bool, true)<br/>            config  = optional(string, null)<br/>          }), {})<br/>          binaries_syncer = optional(object({<br/>            enabled = optional(bool, true)<br/>          }), {})<br/>          detailed_monitoring_enabled = optional(bool, false)<br/>          ssm_enabled                 = optional(bool, false)<br/>          user_data = optional(object({<br/>            enabled               = optional(bool, true)<br/>            template              = optional(string, null)<br/>            content               = optional(string, null)<br/>            pre_install           = optional(string, "")<br/>            post_install          = optional(string, "")<br/>            debug_logging_enabled = optional(bool, false)<br/>          }), {})<br/>          instance_allocation_strategy  = optional(string, "lowest-price")<br/>          instance_max_spot_price       = optional(string, null)<br/>          instance_target_capacity_type = optional(string, "spot")<br/>          instance_type_priorities      = optional(map(number), null)<br/>          instance_types                = list(string)<br/>          additional_security_group_ids = optional(list(string), [])<br/>          instance_profile = optional(object({<br/>            name = string<br/>          }), null)<br/>          enable_on_demand_failover_for_errors = optional(list(string), [])<br/>          scale_errors = optional(list(string), [<br/>            "UnfulfillableCapacity",<br/>            "MaxSpotInstanceCountExceeded",<br/>            "TargetCapacityLimitExceededException",<br/>            "RequestLimitExceeded",<br/>            "ResourceLimitExceeded",<br/>            "MaxSpotInstanceCountExceeded",<br/>            "MaxSpotFleetRequestCountExceeded",<br/>            "InsufficientInstanceCapacity",<br/>            "InsufficientCapacityOnHost",<br/>          ])<br/>          subnet_ids = optional(list(string), null)<br/>          vpc_id     = optional(string, null)<br/>          cpu_options = optional(object({<br/>            core_count            = optional(number)<br/>            threads_per_core      = optional(number)<br/>            amd_sev_snp           = optional(string)<br/>            nested_virtualization = optional(string)<br/>          }), null)<br/>          placement = optional(object({<br/>            affinity                = optional(string)<br/>            availability_zone       = optional(string)<br/>            group_id                = optional(string)<br/>            group_name              = optional(string)<br/>            host_id                 = optional(string)<br/>            host_resource_group_arn = optional(string)<br/>            spread_domain           = optional(string)<br/>            tenancy                 = optional(string)<br/>            partition_number        = optional(number)<br/>          }), null)<br/>          license_specifications = optional(list(object({<br/>            license_configuration_arn = string<br/>          })), [])<br/>          use_dedicated_host = optional(bool, false)<br/>          log_files = optional(list(object({<br/>            log_group_name   = string<br/>            prefix_log_group = bool<br/>            file_path        = string<br/>            log_stream_name  = string<br/>            log_class        = optional(string, "STANDARD")<br/>          })), null)<br/>          tags = optional(map(string), {})<br/>        })<br/>      })<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_tenant_configs"></a> [tenant\_configs](#input\_tenant\_configs) | n/a | <pre>object({<br/>    ecr_registries = list(string)<br/>    tags           = map(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ec2_runners_ami_name_map"></a> [ec2\_runners\_ami\_name\_map](#output\_ec2\_runners\_ami\_name\_map) | Map of EC2 runner keys to the AMI names used for each runner. |
| <a name="output_ec2_runners_arn_map"></a> [ec2\_runners\_arn\_map](#output\_ec2\_runners\_arn\_map) | Map of EC2 runner keys to their IAM role ARNs. |
| <a name="output_ec2_runners_labels_map"></a> [ec2\_runners\_labels\_map](#output\_ec2\_runners\_labels\_map) | Map of EC2 runner keys to their base and extra GitHub labels. |
| <a name="output_event_bus_name"></a> [event\_bus\_name](#output\_event\_bus\_name) | Name of the EventBridge event bus used by the webhook relay. |
| <a name="output_subnet_cidr_blocks"></a> [subnet\_cidr\_blocks](#output\_subnet\_cidr\_blocks) | Map of EC2 runner subnet IDs to their CIDR blocks. |
| <a name="output_webhook_endpoint"></a> [webhook\_endpoint](#output\_webhook\_endpoint) | Public HTTPS endpoint URL for the GitHub Actions webhook relay. |
<!-- END_TF_DOCS -->
