# EC2 Runner Deployment

This module deploys Forge EC2 runner pools through the upstream
`terraform-aws-github-runner` multi-runner module.

## Why This Module Exists

The experimental input lets each runner configuration select a typed
orchestration provider and a typed compute provider. Webhook orchestration owns
runner lifecycle, capacity, startup timing, GitHub scope, label matching,
queues, scale-up, scale-down, pool, and retry settings. The common Lambda block
remains provider-neutral and owns only runtime, architecture, networking, role,
and tag overrides. Forge enriches each configuration with its required hooks, IAM
policies, bootstrap content, logging, and tags, then passes the canonical map
through `experimental.multi_runner_config`.

Global experimental settings own the GitHub App and API client, common Lambda
substrate, webhook orchestration defaults and artifacts, the SSM housekeeper
artifact and KMS key, logging defaults, and EC2 network defaults. EC2 supports
custom AMIs, macOS/Windows, dedicated hosts, and larger hardware profiles.

## What It Manages

- The upstream multi-runner control plane for webhook, scale-up, scale-down, and ephemeral runner registration.
- Per-configuration label matching, warm pool schedules, and capacity limits.
- EC2 AMI, instance type, storage, user data, tag, and logging-hook configuration.
- Shared KMS key material, Lambda egress security group, and EC2 AMI and tag helpers.

## Operational Notes

- This is a breaking input migration: every `runner_specs` entry uses the full
  nested v2 shape and must contain `runner`, `orchestration_provider.webhook`, and
  `compute_provider.ec2`. The `orchestration_provider.webhook.runner` block owns the
  `ephemeral` and `jit_config_enabled` lifecycle modes, `maximum_count` capacity
  limit, and `boot_time_in_minutes` startup estimate. Matching, queue,
  `lambda.scale.up`, `lambda.scale.down`, pool, and retry settings stay inside
  that provider block. The legacy flat EC2 shape is not accepted.
- The runner-control archive is selected once at
  `orchestration_provider.webhook.lambda.artifact`. Per-runner webhook Lambda blocks own
  only scale and pool runtime settings and cannot select an artifact.
- The SSM housekeeper has its own artifact selector under
  `ssm.housekeeper.lambda.artifact`; Forge points the global selector at the
  runner control-plane archive.
- Forge still owns scheduled AMI refresh, so EC2 runner configurations require
  a non-null, module-managed `ami` block and cannot select
  `ami.id_ssm_parameter`. The
  refresh uses the same default AMI name filter as the upstream EC2 provider for
  each runner OS and architecture; values in `ami.filter` override those
  defaults.
- External runner roles and instance profiles are supported as a pair. Their
  owner must provision Forge's EC2-tag and hook-SSM permissions because the
  module does not modify externally managed IAM resources.
- The upstream v2 ref is experimental and mutable. It does not include an
  automatic state move from the prior experimental `module.runner_stacks`
  address to `module.runner_configs`, or from the stable v1 graph. Migrate any
  existing state explicitly and inspect plans for unexpected replacement or
  naming collisions before rollout.
- Forge currently supplies the v7.10.1 Lambda release artifacts to the
  experimental Terraform graph. Keep rollout gated until artifact compatibility
  is verified or exact-ref artifacts are published.
- Label sets are the API contract with tenant workflows, so exact matching matters.
- Use warm pools only where startup latency justifies the idle cost.
- Subnet IP capacity and EC2 capacity errors are expected operational signals, not unusual exceptions.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.7.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.47 |
| <a name="requirement_external"></a> [external](#requirement\_external) | >= 2.3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.47 |
| <a name="provider_external"></a> [external](#provider\_external) | >= 2.3 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ec2_update_runner_ssm_ami"></a> [ec2\_update\_runner\_ssm\_ami](#module\_ec2\_update\_runner\_ssm\_ami) | ./ec2_update_runner_ssm_ami | n/a |
| <a name="module_ec2_update_runner_tags"></a> [ec2\_update\_runner\_tags](#module\_ec2\_update\_runner\_tags) | ./ec2_update_runner_tags | n/a |
| <a name="module_runners"></a> [runners](#module\_runners) | git::https://github.com/github-aws-runners/terraform-aws-github-runner.git//modules/multi-runner | experimental-multi-runner-config-v2-20260805 |

## Resources

| Name | Type |
|------|------|
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
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Assuming single region for now. | `string` | n/a | yes |
| <a name="input_network_configs"></a> [network\_configs](#input\_network\_configs) | n/a | <pre>object({<br/>    vpc_id            = string<br/>    subnet_ids        = list(string)<br/>    lambda_vpc_id     = string<br/>    lambda_subnet_ids = list(string)<br/>  })</pre> | n/a | yes |
| <a name="input_runner_configs"></a> [runner\_configs](#input\_runner\_configs) | n/a | <pre>object({<br/>    env                       = string<br/>    prefix                    = string<br/>    ghes_url                  = string<br/>    log_level                 = string<br/>    logging_retention_in_days = string<br/>    github_app = object({<br/>      key_base64     = string<br/>      id             = string<br/>      webhook_secret = string<br/>    })<br/>    runner_iam_role_managed_policy_arns = list(string)<br/>    runner_specs = map(object({<br/>      tags = optional(map(string), {})<br/><br/>      runner = object({<br/>        os                     = string<br/>        architecture           = string<br/>        disable_default_labels = optional(bool, null)<br/>        extra_labels           = optional(list(string), null)<br/>        group_name             = optional(string, null)<br/>        name_prefix            = optional(string, null)<br/>        run_as_root            = optional(bool, null)<br/>        run_as                 = optional(string, null)<br/>        auto_update_disabled   = optional(bool, null)<br/>        tags                   = optional(map(string), {})<br/>        hooks = optional(object({<br/>          job_started   = optional(string, null)<br/>          job_completed = optional(string, null)<br/>        }), {})<br/>        iam = optional(object({<br/>          role = optional(object({<br/>            arn = string<br/>          }), null)<br/>          managed_policy_arns          = optional(map(string), null)<br/>          additional_trust_policy_json = optional(string, null)<br/>          path                         = optional(string, null)<br/>          permissions_boundary         = optional(string, null)<br/>        }), {})<br/>      })<br/><br/>      lambda = optional(object({<br/>        runtime            = optional(string, null)<br/>        architecture       = optional(string, null)<br/>        subnet_ids         = optional(list(string), null)<br/>        security_group_ids = optional(list(string), null)<br/>        tags               = optional(map(string), {})<br/>        role = optional(object({<br/>          path                 = optional(string, null)<br/>          permissions_boundary = optional(string, null)<br/>        }), {})<br/>      }), {})<br/><br/>      orchestration_provider = object({<br/>        webhook = optional(object({<br/>          runner = object({<br/>            boot_time_in_minutes = optional(number, null)<br/>            ephemeral            = optional(bool, null)<br/>            jit_config_enabled   = optional(bool, null)<br/>            maximum_count        = number<br/>          })<br/><br/>          github = optional(object({<br/>            organization_runners = optional(bool, false)<br/>          }), {})<br/><br/>          matcherConfig = object({<br/>            labelMatchers           = list(list(string))<br/>            exactMatch              = optional(bool, false)<br/>            bidirectionalLabelMatch = optional(bool, false)<br/>            priority                = optional(number, 999)<br/>            enableDynamicLabels     = optional(bool, false)<br/>            awsDynamicLabelsPolicy = optional(object({<br/>              blocked_keys = optional(list(string), [])<br/>              restricted_keys = optional(map(object({<br/>                allowed = optional(list(string), [])<br/>                denied  = optional(list(string), [])<br/>                max     = optional(string, null)<br/>              })), {})<br/>            }), null)<br/>          })<br/><br/>          queue = optional(object({<br/>            delay_webhook_event            = optional(number, null)<br/>            job_queue_retention_in_seconds = optional(number, null)<br/>            visibility_timeout_seconds     = optional(number, null)<br/>            redrive_build_queue = optional(object({<br/>              enabled         = optional(bool, null)<br/>              maxReceiveCount = optional(number, null)<br/>            }), null)<br/>            tags = optional(map(string), {})<br/>          }), {})<br/><br/>          lambda = optional(object({<br/>            scale = optional(object({<br/>              up = optional(object({<br/>                memory_size                    = optional(number, null)<br/>                timeout                        = optional(number, null)<br/>                reserved_concurrent_executions = optional(number, null)<br/>                job_queued_check_enabled       = optional(bool, null)<br/>                event_source_mapping = optional(object({<br/>                  batch_size                         = optional(number, null)<br/>                  maximum_batching_window_in_seconds = optional(number, null)<br/>                }), {})<br/>                tags = optional(map(string), {})<br/>              }), {})<br/>              down = optional(object({<br/>                memory_size                     = optional(number, null)<br/>                timeout                         = optional(number, null)<br/>                schedule_expression             = optional(string, null)<br/>                minimum_running_time_in_minutes = optional(number, null)<br/>                idle_config = optional(list(object({<br/>                  cron             = string<br/>                  timeZone         = string<br/>                  idleCount        = number<br/>                  evictionStrategy = optional(string, "oldest_first")<br/>                })), null)<br/>                tags = optional(map(string), {})<br/>              }), {})<br/>            }), {})<br/>            pool = optional(object({<br/>              memory_size                    = optional(number, null)<br/>              timeout                        = optional(number, null)<br/>              reserved_concurrent_executions = optional(number, null)<br/>              config = optional(list(object({<br/>                schedule_expression          = string<br/>                schedule_expression_timezone = optional(string)<br/>                size                         = number<br/>              })), null)<br/>              include_busy_runners = optional(bool, null)<br/>              runner_owner         = optional(string, null)<br/>              tags                 = optional(map(string), {})<br/>            }), {})<br/>          }), {})<br/><br/>          job_retry = optional(object({<br/>            enabled          = optional(bool, false)<br/>            delay_in_seconds = optional(number, 300)<br/>            delay_backoff    = optional(number, 2)<br/>            max_attempts     = optional(number, 1)<br/>            tags             = optional(map(string), {})<br/>            lambda = optional(object({<br/>              memory_size                    = optional(number, 256)<br/>              reserved_concurrent_executions = optional(number, 1)<br/>              timeout                        = optional(number, 30)<br/>            }), {})<br/>          }), {})<br/>        }), null)<br/>      })<br/><br/>      ssm = optional(object({<br/>        paths = optional(object({<br/>          root   = optional(string, null)<br/>          tokens = optional(string, null)<br/>          config = optional(string, null)<br/>        }), {})<br/>        tags = optional(map(string), {})<br/>        parameters = optional(object({<br/>          tags = optional(map(string), {})<br/>        }), {})<br/>        housekeeper = optional(object({<br/>          schedule_expression = optional(string, null)<br/>          state               = optional(string, null)<br/>          tags                = optional(map(string), {})<br/>          lambda = optional(object({<br/>            artifact = optional(object({<br/>              zip = optional(string, null)<br/>              s3 = optional(object({<br/>                key            = string<br/>                object_version = optional(string, null)<br/>              }), null)<br/>            }), {})<br/>            memory_size = optional(number, null)<br/>            timeout     = optional(number, null)<br/>          }), {})<br/>          config = optional(object({<br/>            tokenPath      = optional(string, null)<br/>            minimumDaysOld = optional(number, null)<br/>            dryRun         = optional(bool, null)<br/>          }), {})<br/>        }), {})<br/>      }), {})<br/><br/>      observability = optional(object({<br/>        logs = optional(object({<br/>          level             = optional(string, null)<br/>          retention_in_days = optional(number, null)<br/>          kms_key_id        = optional(string, null)<br/>          class             = optional(string, null)<br/>          tags              = optional(map(string), {})<br/>        }), {})<br/>        tracing = optional(object({<br/>          mode                  = optional(string, null)<br/>          capture_http_requests = optional(bool, null)<br/>          capture_error         = optional(bool, null)<br/>        }), {})<br/>        metrics = optional(object({<br/>          enable    = optional(bool, null)<br/>          namespace = optional(string, null)<br/>          metric = optional(object({<br/>            enable_github_app_rate_limit = optional(bool, null)<br/>            enable_job_retry             = optional(bool, null)<br/>          }), {})<br/>        }), {})<br/>      }), {})<br/><br/>      compute_provider = object({<br/>        ec2 = optional(object({<br/>          metadata_options = optional(object({<br/>            instance_metadata_tags      = optional(string, "enabled")<br/>            http_endpoint               = optional(string, "enabled")<br/>            http_tokens                 = optional(string, "required")<br/>            http_put_response_hop_limit = optional(number, 1)<br/>          }), {})<br/>          ami = optional(object({<br/>            filter = optional(map(list(string)), { state = ["available"] })<br/>            owners = optional(list(string), ["amazon"])<br/>            id_ssm_parameter = optional(object({<br/>              arn = string<br/>            }), null)<br/>            kms_key = optional(object({<br/>              arn = string<br/>            }), null)<br/>          }), null)<br/>          block_device_mappings = optional(list(object({<br/>            delete_on_termination      = optional(bool, true)<br/>            device_name                = optional(string, "/dev/xvda")<br/>            encrypted                  = optional(bool, true)<br/>            iops                       = optional(number)<br/>            kms_key_id                 = optional(string)<br/>            snapshot_id                = optional(string)<br/>            throughput                 = optional(number)<br/>            volume_initialization_rate = optional(number)<br/>            volume_size                = number<br/>            volume_type                = optional(string, "gp3")<br/>            })), [{<br/>            volume_size = 30<br/>          }])<br/>          create_service_linked_role_spot = optional(bool, false)<br/>          credit_specification            = optional(string, null)<br/>          ebs_optimized                   = optional(bool, false)<br/>          cloudwatch_agent = optional(object({<br/>            enabled = optional(bool, true)<br/>            config  = optional(string, null)<br/>          }), {})<br/>          binaries_syncer = optional(object({<br/>            enabled = optional(bool, null)<br/>          }), {})<br/>          detailed_monitoring_enabled = optional(bool, false)<br/>          ssm_enabled                 = optional(bool, false)<br/>          user_data = optional(object({<br/>            enabled               = optional(bool, true)<br/>            template              = optional(string, null)<br/>            content               = optional(string, null)<br/>            pre_install           = optional(string, "")<br/>            post_install          = optional(string, "")<br/>            debug_logging_enabled = optional(bool, false)<br/>          }), {})<br/>          instance_allocation_strategy   = optional(string, "lowest-price")<br/>          instance_max_spot_price        = optional(string, null)<br/>          instance_target_capacity_type  = optional(string, "spot")<br/>          instance_type_priorities       = optional(map(number), null)<br/>          instance_types                 = list(string)<br/>          additional_security_group_ids  = optional(list(string), null)<br/>          managed_security_group_enabled = optional(bool, null)<br/>          egress_rules = optional(list(object({<br/>            cidr_blocks      = list(string)<br/>            ipv6_cidr_blocks = list(string)<br/>            prefix_list_ids  = list(string)<br/>            from_port        = number<br/>            protocol         = string<br/>            security_groups  = list(string)<br/>            self             = bool<br/>            to_port          = number<br/>            description      = string<br/>          })), null)<br/>          instance_profile_path         = optional(string, null)<br/>          key_name                      = optional(string, null)<br/>          associate_public_ipv4_address = optional(bool, null)<br/>          instance_profile = optional(object({<br/>            name = string<br/>          }), null)<br/>          enable_on_demand_failover_for_errors = optional(list(string), [])<br/>          scale_errors = optional(list(string), [<br/>            "UnfulfillableCapacity",<br/>            "MaxSpotInstanceCountExceeded",<br/>            "TargetCapacityLimitExceededException",<br/>            "RequestLimitExceeded",<br/>            "ResourceLimitExceeded",<br/>            "MaxSpotInstanceCountExceeded",<br/>            "MaxSpotFleetRequestCountExceeded",<br/>            "InsufficientInstanceCapacity",<br/>            "InsufficientCapacityOnHost",<br/>          ])<br/>          subnet_ids = optional(list(string), null)<br/>          vpc_id     = optional(string, null)<br/>          cpu_options = optional(object({<br/>            core_count            = optional(number)<br/>            threads_per_core      = optional(number)<br/>            amd_sev_snp           = optional(string)<br/>            nested_virtualization = optional(string)<br/>          }), null)<br/>          placement = optional(object({<br/>            affinity                = optional(string)<br/>            availability_zone       = optional(string)<br/>            group_id                = optional(string)<br/>            group_name              = optional(string)<br/>            host_id                 = optional(string)<br/>            host_resource_group_arn = optional(string)<br/>            spread_domain           = optional(string)<br/>            tenancy                 = optional(string)<br/>            partition_number        = optional(number)<br/>          }), null)<br/>          license_specifications = optional(list(object({<br/>            license_configuration_arn = string<br/>          })), [])<br/>          use_dedicated_host = optional(bool, false)<br/>          log_files = optional(list(object({<br/>            log_group_name   = string<br/>            prefix_log_group = bool<br/>            file_path        = string<br/>            log_stream_name  = string<br/>            log_class        = optional(string, "STANDARD")<br/>          })), null)<br/>          tags = optional(map(string), {})<br/>        }), null)<br/>      })<br/><br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_tenant_configs"></a> [tenant\_configs](#input\_tenant\_configs) | n/a | <pre>object({<br/>    ecr_registries = list(string)<br/>    tags           = map(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ec2_runners_ami_name_map"></a> [ec2\_runners\_ami\_name\_map](#output\_ec2\_runners\_ami\_name\_map) | Map of EC2 runner keys to the AMI names used for each runner. |
| <a name="output_ec2_runners_arn_map"></a> [ec2\_runners\_arn\_map](#output\_ec2\_runners\_arn\_map) | Map of EC2 runner keys to their IAM role ARNs. |
| <a name="output_ec2_runners_labels_map"></a> [ec2\_runners\_labels\_map](#output\_ec2\_runners\_labels\_map) | Map of EC2 runner keys to their base and extra GitHub labels. |
| <a name="output_event_bus_name"></a> [event\_bus\_name](#output\_event\_bus\_name) | Name of the EventBridge event bus used by the webhook relay. |
| <a name="output_subnet_cidr_blocks"></a> [subnet\_cidr\_blocks](#output\_subnet\_cidr\_blocks) | Map of EC2 runner subnet IDs to their CIDR blocks. |
| <a name="output_webhook_endpoint"></a> [webhook\_endpoint](#output\_webhook\_endpoint) | Public HTTPS endpoint URL for the GitHub Actions webhook relay. |
<!-- END_TF_DOCS -->
