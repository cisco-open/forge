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

  # Keep Forge's public input aligned with the nested v2 EC2 contract while
  # the upstream module remains on its stable v1 multi_runner_config path.
  multi_runner_config_v1 = {
    for key, runner_config in local.ec2_runner_configs :
    key => {
      runner_config = {
        runner_os                   = runner_config.runner_os
        runner_architecture         = runner_config.runner_architecture
        runner_metadata_options     = local.ec2_compute_provider[key].metadata_options
        runner_extra_labels         = runner_config.extra_labels
        runner_group_name           = var.runner_configs.runner_group_name
        runner_run_as               = runner_config.runner_user
        runners_maximum_count       = runner_config.max_instances
        enable_ephemeral_runners    = true
        enable_organization_runners = true

        ami = {
          filter               = local.ec2_compute_provider[key].ami.filter
          owners               = local.ec2_compute_provider[key].ami.owners
          id_ssm_parameter_arn = try(local.ec2_compute_provider[key].ami.id_ssm_parameter.arn, null)
          kms_key_arn          = try(local.ec2_compute_provider[key].ami.kms_key.arn, null)
        }

        block_device_mappings                = local.ec2_compute_provider[key].block_device_mappings
        create_service_linked_role_spot      = local.ec2_compute_provider[key].create_service_linked_role_spot
        credit_specification                 = local.ec2_compute_provider[key].credit_specification
        ebs_optimized                        = local.ec2_compute_provider[key].ebs_optimized
        enable_cloudwatch_agent              = local.ec2_compute_provider[key].cloudwatch_agent.enabled
        cloudwatch_config                    = local.ec2_compute_provider[key].cloudwatch_agent.config
        enable_runner_binaries_syncer        = local.ec2_compute_provider[key].binaries_syncer.enabled
        enable_runner_detailed_monitoring    = local.ec2_compute_provider[key].detailed_monitoring_enabled
        enable_ssm_on_runners                = local.ec2_compute_provider[key].ssm_enabled
        enable_userdata                      = local.ec2_compute_provider[key].user_data.enabled
        userdata_template                    = local.ec2_compute_provider[key].user_data.template
        userdata_content                     = local.ec2_compute_provider[key].user_data.content
        userdata_pre_install                 = local.ec2_compute_provider[key].user_data.pre_install
        userdata_post_install                = local.ec2_compute_provider[key].user_data.post_install
        instance_allocation_strategy         = local.ec2_compute_provider[key].instance_allocation_strategy
        instance_max_spot_price              = local.ec2_compute_provider[key].instance_max_spot_price
        instance_target_capacity_type        = local.ec2_compute_provider[key].instance_target_capacity_type
        instance_type_priorities             = local.ec2_compute_provider[key].instance_type_priorities
        instance_types                       = local.ec2_compute_provider[key].instance_types
        runner_additional_security_group_ids = local.ec2_compute_provider[key].additional_security_group_ids
        enable_on_demand_failover_for_errors = local.ec2_compute_provider[key].enable_on_demand_failover_for_errors
        scale_errors                         = local.ec2_compute_provider[key].scale_errors
        subnet_ids                           = local.ec2_compute_provider[key].subnet_ids
        vpc_id                               = local.ec2_compute_provider[key].vpc_id
        cpu_options                          = local.ec2_compute_provider[key].cpu_options
        placement                            = local.ec2_compute_provider[key].placement
        license_specifications               = local.ec2_compute_provider[key].license_specifications
        use_dedicated_host                   = local.ec2_compute_provider[key].use_dedicated_host
        runner_log_files                     = local.ec2_compute_provider[key].log_files
        runner_ec2_tags                      = local.ec2_compute_provider[key].tags

        delay_webhook_event                                            = 0
        job_queue_retention_in_seconds                                 = 172800
        lambda_event_source_mapping_batch_size                         = runner_config.lambda_event_source_mapping_batch_size
        lambda_event_source_mapping_maximum_batching_window_in_seconds = runner_config.lambda_event_source_mapping_maximum_batching_window_in_seconds
        enable_job_queued_check                                        = false
        scale_down_schedule_expression                                 = "cron(*/5 * * * ? *)"
        minimum_running_time_in_minutes                                = runner_config.min_run_time
        pool_config                                                    = runner_config.pool_config
        pool_runner_owner                                              = var.runner_configs.ghes_org

        runner_hook_job_started = templatefile(
          "${local.user_data_prefix}/hook_job_started_${runner_config.runner_os}.tftpl",
          {
            param_name = aws_ssm_parameter.hook_job_started[runner_config.runner_os].name
            region     = var.aws_region
          }
        )
        runner_hook_job_completed = templatefile(
          "${local.user_data_prefix}/hook_job_completed_${runner_config.runner_os}.tftpl",
          {
            param_name = aws_ssm_parameter.hook_job_completed[runner_config.runner_os].name
            region     = var.aws_region
          }
        )
        runner_iam_role_managed_policy_arns = concat(
          var.runner_configs.runner_iam_role_managed_policy_arns,
          [
            aws_iam_policy.ec2_tags.arn,
            aws_iam_policy.runner_hooks_ssm_read.arn,
          ],
        )
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

      redrive_build_queue = runner_config.redrive_build_queue
    }
  }
}
