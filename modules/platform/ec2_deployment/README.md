# Compute Runner Deployment

This module deploys Forge EC2 and Lambda MicroVM runner pools through the
upstream `terraform-aws-github-runner` multi-runner module. The historical
`ec2_deployment` module path is retained.

## Why This Module Exists

Provider-aware runner lanes let a tenant choose a full EC2 VM or a Lambda
MicroVM per label set while sharing the same webhook and runner control plane.
Forge keeps EC2 for workloads that need custom AMIs, macOS/Windows, dedicated
hosts, or larger hardware, and can use MicroVMs for Linux workloads supported
by the MicroVM image catalog.

## What It Manages

- The upstream multi-runner control plane for webhook, scale-up, scale-down, and ephemeral runner registration.
- Per-lane label matching, provider selection, warm pool schedules, and capacity limits.
- EC2 AMI, instance type, storage, user data, tag, and logging-hook configuration.
- MicroVM image, network connector, idle policy, logging, runtime, and IAM configuration.
- Shared KMS key material and Lambda egress security group, plus EC2-only AMI and tag helpers.

## Operational Notes

- This is a breaking input migration: every `runner_specs` entry must contain
  exactly one non-null `compute_provider.ec2` or `compute_provider.microvm`
  block. The legacy flat EC2 shape is not accepted.
- The upstream v2 path changes Terraform resource addresses from the v1 runner
  modules to provider-oriented runner stacks; this module does not include an
  in-place state migration.
- The upstream dependency is pinned to draft PR #5260. Until its provider-aware
  Lambda artifacts are released, plans require matching PR-built ZIPs supplied
  with `USE_CACHE` and `CACHE_PATH`.
- MicroVM lanes use the upstream module-managed execution role so Forge's
  tenant-assumption, ECR, and global-lock policies apply to the runtime identity.
- Every compute runner is ephemeral and is expected to register for one job and then be reaped.
- Label sets are the API contract with tenant workflows, so exact matching matters.
- Cold starts vary by provider; use warm pools only where latency justifies the idle cost.
- Subnet IP capacity and provider capacity errors are expected operational signals, not unusual exceptions.

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
| <a name="module_runners"></a> [runners](#module\_runners) | git::https://github.com/github-aws-runners/terraform-aws-github-runner.git//modules/multi-runner | 961c1208a3831d19af8c0cfb43a7ed8b2d81e34b |

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
| <a name="input_runner_configs"></a> [runner\_configs](#input\_runner\_configs) | n/a | <pre>object({<br/>    env                       = string<br/>    prefix                    = string<br/>    ghes_url                  = string<br/>    ghes_org                  = string<br/>    log_level                 = string<br/>    logging_retention_in_days = string<br/>    github_app = object({<br/>      key_base64     = string<br/>      id             = string<br/>      webhook_secret = string<br/>    })<br/>    runner_iam_role_managed_policy_arns = list(string)<br/>    runner_group_name                   = string<br/>    runner_specs = map(object({<br/>      runner_labels         = list(string)<br/>      runner_os             = string<br/>      runner_architecture   = string<br/>      extra_labels          = list(string)<br/>      enable_dynamic_labels = optional(bool, false)<br/>      aws_dynamic_labels_policy = optional(object({<br/>        blocked_keys = optional(list(string), [])<br/>        restricted_keys = optional(map(object({<br/>          allowed = optional(list(string), [])<br/>          denied  = optional(list(string), [])<br/>          max     = optional(string, null)<br/>        })), {})<br/>      }), null)<br/>      lambda_event_source_mapping_batch_size                         = optional(number, 10)<br/>      lambda_event_source_mapping_maximum_batching_window_in_seconds = optional(number, 0)<br/>      redrive_build_queue = optional(object({<br/>        enabled         = optional(bool, true)<br/>        maxReceiveCount = optional(number, 10)<br/>      }), {})<br/>      max_instances = number<br/>      min_run_time  = number<br/>      pool_config = list(object({<br/>        size                         = number<br/>        schedule_expression          = string<br/>        schedule_expression_timezone = string<br/>      }))<br/>      runner_user = string<br/>      compute_provider = object({<br/>        ec2 = optional(object({<br/>          ami_filter = object({<br/>            name  = list(string)<br/>            state = list(string)<br/>          })<br/>          ami_kms_key_arn = string<br/>          ami_owners      = list(string)<br/>          instance_types  = list(string)<br/>          license_specifications = optional(list(object({<br/>            license_configuration_arn = string<br/>          })), null)<br/>          placement = optional(object({<br/>            affinity                = optional(string)<br/>            availability_zone       = optional(string)<br/>            group_id                = optional(string)<br/>            group_name              = optional(string)<br/>            host_id                 = optional(string)<br/>            host_resource_group_arn = optional(string)<br/>            spread_domain           = optional(string)<br/>            tenancy                 = optional(string)<br/>            partition_number        = optional(number)<br/>          }), null)<br/>          use_dedicated_host            = optional(bool, false)<br/>          enable_userdata               = bool<br/>          instance_target_capacity_type = string<br/>          vpc_id                        = optional(string, null)<br/>          subnet_ids                    = optional(list(string), null)<br/>          scale_errors                  = optional(list(string), [])<br/>          block_device_mappings = list(object({<br/>            delete_on_termination      = bool<br/>            device_name                = string<br/>            encrypted                  = bool<br/>            iops                       = number<br/>            kms_key_id                 = string<br/>            snapshot_id                = string<br/>            throughput                 = number<br/>            volume_initialization_rate = optional(number)<br/>            volume_size                = number<br/>            volume_type                = string<br/>          }))<br/>        }), null)<br/>        microvm = optional(object({<br/>          image_identifier          = string<br/>          image_version             = optional(string, null)<br/>          egress_network_connectors = optional(list(string), [])<br/>          idle_policy = optional(object({<br/>            max_idle_duration_seconds  = number<br/>            suspended_duration_seconds = number<br/>            auto_resume_enabled        = bool<br/>          }), null)<br/>          logging = optional(object({<br/>            cloud_watch = optional(object({<br/>              log_group  = optional(string, null)<br/>              log_stream = optional(string, null)<br/>            }), null)<br/>            disabled = optional(bool, false)<br/>          }), null)<br/>          run_hook_payload            = optional(string, null)<br/>          maximum_duration_in_seconds = optional(number, null)<br/>          environment_variables       = optional(map(string), {})<br/>          tags                        = optional(map(string), {})<br/>          iam = optional(object({<br/>            resource_arns = optional(list(string), ["*"])<br/>            actions = optional(object({<br/>              scale_up   = optional(list(string), null)<br/>              scale_down = optional(list(string), null)<br/>            }), {})<br/>            additional_policy_json = optional(object({<br/>              scale_up = optional(string, null)<br/>            }), {})<br/>            managed_policy_arns = optional(object({<br/>              scale_up = optional(string, null)<br/>              pool     = optional(string, null)<br/>            }), {})<br/>          }), {})<br/>        }), null)<br/>      })<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_tenant_configs"></a> [tenant\_configs](#input\_tenant\_configs) | n/a | <pre>object({<br/>    ecr_registries = list(string)<br/>    tags           = map(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ec2_runners_ami_name_map"></a> [ec2\_runners\_ami\_name\_map](#output\_ec2\_runners\_ami\_name\_map) | Map of EC2 runner keys to the AMI names used for each runner. |
| <a name="output_ec2_runners_arn_map"></a> [ec2\_runners\_arn\_map](#output\_ec2\_runners\_arn\_map) | Map of EC2 runner keys to their IAM role ARNs. |
| <a name="output_ec2_runners_labels_map"></a> [ec2\_runners\_labels\_map](#output\_ec2\_runners\_labels\_map) | Map of EC2 runner keys to their base and extra GitHub labels. |
| <a name="output_ec2_runners_map"></a> [ec2\_runners\_map](#output\_ec2\_runners\_map) | Map of EC2 runner keys to their provider-specific resources. |
| <a name="output_event_bus_name"></a> [event\_bus\_name](#output\_event\_bus\_name) | Name of the EventBridge event bus used by the webhook relay. |
| <a name="output_microvm_runners_arn_map"></a> [microvm\_runners\_arn\_map](#output\_microvm\_runners\_arn\_map) | Map of MicroVM runner keys to their execution role ARNs. |
| <a name="output_microvm_runners_labels_map"></a> [microvm\_runners\_labels\_map](#output\_microvm\_runners\_labels\_map) | Map of MicroVM runner keys to their base and extra GitHub labels. |
| <a name="output_microvm_runners_map"></a> [microvm\_runners\_map](#output\_microvm\_runners\_map) | Map of MicroVM runner keys to their provider-specific resources. |
| <a name="output_runners_arn_map"></a> [runners\_arn\_map](#output\_runners\_arn\_map) | Map of runner keys to the IAM role ARNs used by their compute runtime. |
| <a name="output_runners_labels_map"></a> [runners\_labels\_map](#output\_runners\_labels\_map) | Map of runner keys to their base and extra GitHub labels. |
| <a name="output_subnet_cidr_blocks"></a> [subnet\_cidr\_blocks](#output\_subnet\_cidr\_blocks) | Map of EC2 runner subnet IDs to their CIDR blocks. |
| <a name="output_webhook_endpoint"></a> [webhook\_endpoint](#output\_webhook\_endpoint) | Public HTTPS endpoint URL for the GitHub Actions webhook relay. |
<!-- END_TF_DOCS -->
