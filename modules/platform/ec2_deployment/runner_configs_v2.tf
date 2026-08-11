locals {
  ec2_runner_configs = var.runner_configs.runner_specs

  active_ec2_runner_oses = {
    for key, runner_config in local.ec2_runner_configs :
    key => runner_config.runner_os
  }

  active_ec2_subnet_ids = toset(flatten([
    for runner_config in values(local.ec2_runner_configs) :
    runner_config.compute_provider.ec2.subnet_ids == null ? var.network_configs.subnet_ids : runner_config.compute_provider.ec2.subnet_ids
  ]))

  # This is the upstream EC2 provider's default AMI selection. Normalize it
  # here so the provider and Forge's scheduled AMI refresh use one effective
  # filter map.
  ec2_default_ami_filters = {
    for key, runner_config in local.ec2_runner_configs :
    key => ({
      windows = { name = ["Windows_Server-2022-English-Full-ECS_Optimized-*"] }
      linux   = runner_config.runner_architecture == "arm64" ? { name = ["al2023-ami-2023.*-kernel-6.*-arm64"] } : { name = ["al2023-ami-2023.*-kernel-6.*-x86_64"] }
      osx     = runner_config.runner_architecture == "arm64" ? { name = ["amzn-ec2-macos-15.*-arm64"] } : { name = ["amzn-ec2-macos-15.*"] }
    })[runner_config.runner_os]
  }

  runner_labels = {
    for key, runner_config in var.runner_configs.runner_specs :
    key => concat(runner_config.runner_labels, runner_config.extra_labels)
  }

  runner_iam_role_managed_policy_arns = {
    for policy_index, policy_arn in var.runner_configs.runner_iam_role_managed_policy_arns :
    "forge-${policy_index}" => policy_arn
  }

  forge_ec2_log_files = {
    for key, runner_config in local.ec2_runner_configs :
    key => concat(
      runner_config.runner_os == "windows" ? [] : [
        {
          log_group_name   = "forge-logs"
          prefix_log_group = true
          file_path        = "/var/log/syslog"
          log_stream_name  = "{instance_id}/syslog"
        },
      ],
      [
        {
          log_group_name   = "forge-logs"
          prefix_log_group = true
          file_path        = runner_config.runner_os == "windows" ? "C:/UserData.log" : "/var/log/user-data.log"
          log_stream_name  = "{instance_id}/user-data"
        },
        {
          log_group_name   = "forge-logs"
          prefix_log_group = true
          file_path        = runner_config.runner_os == "windows" ? "C:/actions-runner/_diag/Runner_*.log" : "/opt/actions-runner/_diag/Runner_**.log"
          log_stream_name  = "{instance_id}/runner"
        },
        {
          log_group_name   = "forge-logs"
          prefix_log_group = true
          file_path        = runner_config.runner_os == "windows" ? "C:/Users/Administrator/AppData/Local/Temp/hook_*.log" : "/home/${runner_config.runner_user}/hook.log"
          log_stream_name  = "{instance_id}/hook"
        },
      ],
    )
  }

  ec2_compute_provider = {
    for key, runner_config in local.ec2_runner_configs :
    key => merge(
      runner_config.compute_provider.ec2,
      {
        ami = runner_config.compute_provider.ec2.ami == null ? null : merge(
          runner_config.compute_provider.ec2.ami,
          {
            filter = merge(
              local.ec2_default_ami_filters[key],
              runner_config.compute_provider.ec2.ami.filter,
            )
          }
        )
        user_data = merge(
          runner_config.compute_provider.ec2.user_data,
          {
            template = (
              runner_config.compute_provider.ec2.user_data.content == null
              && runner_config.compute_provider.ec2.user_data.template == null
            ) ? "${local.user_data_prefix}/user_data_${runner_config.runner_os}.tftpl" : runner_config.compute_provider.ec2.user_data.template
            post_install = join("\n", compact([
              runner_config.compute_provider.ec2.user_data.post_install,
              templatefile(
                local.userdata_template_post_install,
                {
                  runner_user    = runner_config.runner_user
                  ecr_registries = var.tenant_configs.ecr_registries
                }
              ),
            ]))
          }
        )
        log_files = coalesce(runner_config.compute_provider.ec2.log_files, local.forge_ec2_log_files[key])
        tags      = merge(var.tenant_configs.tags, runner_config.compute_provider.ec2.tags)
      }
    )
  }

  multi_runner_config_v2 = {
    for key, runner_config in var.runner_configs.runner_specs :
    key => {
      runner = {
        os            = runner_config.runner_os
        architecture  = runner_config.runner_architecture
        extra_labels  = runner_config.extra_labels
        group_name    = var.runner_configs.runner_group_name
        run_as        = runner_config.runner_user
        maximum_count = runner_config.max_instances
        ephemeral     = true
        hooks = {
          job_started = templatefile(
            "${local.user_data_prefix}/hook_job_started_${runner_config.runner_os}.tftpl",
            {
              param_name = aws_ssm_parameter.hook_job_started[runner_config.runner_os].name
              region     = var.aws_region
            }
          )
          job_completed = templatefile(
            "${local.user_data_prefix}/hook_job_completed_${runner_config.runner_os}.tftpl",
            {
              param_name = aws_ssm_parameter.hook_job_completed[runner_config.runner_os].name
              region     = var.aws_region
            }
          )
        }
        iam = {
          managed_policy_arns = merge(
            local.runner_iam_role_managed_policy_arns,
            {
              forge_ec2_tags         = aws_iam_policy.ec2_tags.arn
              forge_runner_hooks_ssm = aws_iam_policy.runner_hooks_ssm_read.arn
            },
          )
        }
      }

      github = {
        organization_runners = true
      }

      queue = {
        delay_webhook_event            = 0
        job_queue_retention_in_seconds = 172800
        event_source_mapping = {
          batch_size                         = runner_config.lambda_event_source_mapping_batch_size
          maximum_batching_window_in_seconds = runner_config.lambda_event_source_mapping_maximum_batching_window_in_seconds
        }
        redrive_build_queue = runner_config.redrive_build_queue
      }

      scale_up = {
        job_queued_check_enabled = false
      }

      scale_down = {
        schedule_expression             = "cron(*/5 * * * ? *)"
        minimum_running_time_in_minutes = runner_config.min_run_time
      }

      pool = {
        config       = runner_config.pool_config
        runner_owner = var.runner_configs.ghes_org
      }

      compute_provider = {
        ec2 = local.ec2_compute_provider[key]
      }

      matcherConfig = {
        labelMatchers = length(runner_config.extra_labels) == 0 ? [runner_config.runner_labels] : concat(
          [runner_config.runner_labels],
          concat([
            for label_count in range(1, length(runner_config.extra_labels) + 1) : concat([
              for start in range(0, length(runner_config.extra_labels) - label_count + 1) :
              concat(runner_config.runner_labels, slice(runner_config.extra_labels, start, start + label_count))
            ])
          ]...)
        )
        exactMatch             = true
        enableDynamicLabels    = runner_config.enable_dynamic_labels
        awsDynamicLabelsPolicy = runner_config.aws_dynamic_labels_policy
      }
    }
  }
}
