locals {
  ec2_runner_configs = var.runner_configs.runner_specs

  effective_runner_users = {
    for key, runner_config in local.ec2_runner_configs :
    key => coalesce(runner_config.runner.run_as_root, false) ? "root" : coalesce(runner_config.runner.run_as, "ec2-user")
  }

  effective_runner_home_directories = {
    for key, runner_config in local.ec2_runner_configs :
    key => runner_config.runner.os == "windows" ? "C:/Users/Administrator" : (
      coalesce(runner_config.runner.run_as_root, false) ? (runner_config.runner.os == "osx" ? "/var/root" : "/root") : "/home/${coalesce(runner_config.runner.run_as, "ec2-user")}"
    )
  }

  effective_runner_hooks = {
    for key, runner_config in local.ec2_runner_configs :
    key => {
      job_started   = runner_config.runner.hooks.job_started == null ? "" : runner_config.runner.hooks.job_started
      job_completed = runner_config.runner.hooks.job_completed == null ? "" : runner_config.runner.hooks.job_completed
    }
  }

  forge_runner_hook_job_started = {
    for key, runner_config in local.ec2_runner_configs :
    key => templatefile(
      "${local.user_data_prefix}/hook_job_started_${runner_config.runner.os}.tftpl",
      {
        param_name = aws_ssm_parameter.hook_job_started[runner_config.runner.os].name
        region     = var.aws_region
      }
    )
  }

  forge_runner_hook_job_completed = {
    for key, runner_config in local.ec2_runner_configs :
    key => templatefile(
      "${local.user_data_prefix}/hook_job_completed_${runner_config.runner.os}.tftpl",
      {
        param_name = aws_ssm_parameter.hook_job_completed[runner_config.runner.os].name
        region     = var.aws_region
      }
    )
  }

  # Run caller hooks in a child shell so `exit` cannot bypass Forge's mandatory
  # lifecycle hook. Keep the empty-hook path byte-identical to the previous
  # configuration to avoid state churn for migrated runner configurations.
  runner_hook_job_started = {
    for key, runner_config in local.ec2_runner_configs :
    key => local.effective_runner_hooks[key].job_started == "" ? local.forge_runner_hook_job_started[key] : join("\n", [
      runner_config.runner.os == "windows" ?
      "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand ${textencodebase64(local.effective_runner_hooks[key].job_started, "UTF-16LE")}" :
      "printf '%s' '${base64encode(local.effective_runner_hooks[key].job_started)}' | base64 --decode | bash",
      local.forge_runner_hook_job_started[key],
    ])
  }

  runner_hook_job_completed = {
    for key, runner_config in local.ec2_runner_configs :
    key => local.effective_runner_hooks[key].job_completed == "" ? local.forge_runner_hook_job_completed[key] : join("\n", [
      runner_config.runner.os == "windows" ?
      "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand ${textencodebase64(local.effective_runner_hooks[key].job_completed, "UTF-16LE")}" :
      "printf '%s' '${base64encode(local.effective_runner_hooks[key].job_completed)}' | base64 --decode | bash",
      local.forge_runner_hook_job_completed[key],
    ])
  }

  active_ec2_runner_oses = {
    for key, runner_config in local.ec2_runner_configs :
    key => runner_config.runner.os
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
      linux   = runner_config.runner.architecture == "arm64" ? { name = ["al2023-ami-2023.*-kernel-6.*-arm64"] } : { name = ["al2023-ami-2023.*-kernel-6.*-x86_64"] }
      osx     = runner_config.runner.architecture == "arm64" ? { name = ["amzn-ec2-macos-15.*-arm64"] } : { name = ["amzn-ec2-macos-15.*"] }
    })[runner_config.runner.os]
  }

  legacy_runner_labels = {
    for key, runner_config in local.ec2_runner_configs :
    key => concat(
      try(runner_config.orchestration.webhook.matcherConfig.labelMatchers[0], []),
      coalesce(runner_config.runner.extra_labels, []),
    )
  }

  # Preserve the former base-plus-extra output (including its order) and append
  # only new labels introduced by additional v2 matchers. The upstream v1 module
  # separately sorts the corresponding set before registering runners.
  runner_labels = {
    for key, runner_config in local.ec2_runner_configs :
    key => concat(
      local.legacy_runner_labels[key],
      distinct([
        for label in flatten([
          for matcher_index, labels in runner_config.orchestration.webhook.matcherConfig.labelMatchers : labels if matcher_index > 0
        ]) : label
        if !contains(local.legacy_runner_labels[key], label)
      ]),
    )
  }

  forge_ec2_log_files = {
    for key, runner_config in local.ec2_runner_configs :
    key => concat(
      runner_config.runner.os == "windows" ? [] : [
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
          file_path        = runner_config.runner.os == "windows" ? "C:/UserData.log" : "/var/log/user-data.log"
          log_stream_name  = "{instance_id}/user-data"
        },
        {
          log_group_name   = "forge-logs"
          prefix_log_group = true
          file_path        = runner_config.runner.os == "windows" ? "C:/actions-runner/_diag/Runner_*.log" : "/opt/actions-runner/_diag/Runner_**.log"
          log_stream_name  = "{instance_id}/runner"
        },
        {
          log_group_name   = "forge-logs"
          prefix_log_group = true
          file_path        = runner_config.runner.os == "windows" ? "C:/Users/Administrator/AppData/Local/Temp/hook_*.log" : "${local.effective_runner_home_directories[key]}/hook.log"
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
            ) ? "${local.user_data_prefix}/user_data_${runner_config.runner.os}.tftpl" : runner_config.compute_provider.ec2.user_data.template
            post_install = join("\n", compact([
              runner_config.compute_provider.ec2.user_data.post_install,
              templatefile(
                local.userdata_template_post_install,
                {
                  runner_user    = local.effective_runner_users[key]
                  runner_home    = local.effective_runner_home_directories[key]
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

  # Preserve Forge-managed runner hooks, policies, bootstrap content, logging,
  # and tags while passing the public nested contract directly to upstream v2.
  multi_runner_config = {
    for key, runner_config in local.ec2_runner_configs :
    key => merge(runner_config, {
      runner = merge(runner_config.runner, {
        hooks = {
          job_started   = local.runner_hook_job_started[key]
          job_completed = local.runner_hook_job_completed[key]
        }
        iam = merge(runner_config.runner.iam, {
          managed_policy_arns = merge(
            coalesce(runner_config.runner.iam.managed_policy_arns, {}),
            runner_config.runner.iam.role == null ? merge(
              {
                for policy_index, policy_arn in var.runner_configs.runner_iam_role_managed_policy_arns :
                "forge-config-${policy_index}" => policy_arn
              },
              {
                forge_ec2_tags              = aws_iam_policy.ec2_tags.arn
                forge_runner_hooks_ssm_read = aws_iam_policy.runner_hooks_ssm_read.arn
              },
            ) : {},
          )
        })
      })
      compute_provider = {
        ec2 = local.ec2_compute_provider[key]
      }
    })
  }

  experimental_config = {
    tags = local.terraform_aws_github_runner_tags

    github = {
      app = var.runner_configs.github_app
      enterprise_server = {
        url = try(trimspace(var.runner_configs.ghes_url), "") == "" ? null : var.runner_configs.ghes_url
      }
    }

    lambda = {
      subnet_ids         = var.network_configs.lambda_subnet_ids
      security_group_ids = [aws_security_group.gh_runner_lambda_egress.id]
      tags               = local.terraform_aws_github_runner_tags
    }

    orchestration = {
      webhook = {
        eventbridge = {
          enable = true
        }
        lambda = {
          artifact = {
            zip = "${data.external.download_lambdas.result.path}/runners.zip"
          }
          webhook = {
            artifact = {
              zip = "${data.external.download_lambdas.result.path}/webhook.zip"
            }
            api_gateway_access_log_settings = {
              destination_arn = aws_cloudwatch_log_group.webhook_api_gateway_access.arn
              format          = local.webhook_api_gateway_access_log_format
            }
          }
        }
      }
    }

    ssm = {
      kms_key_id = aws_kms_key.github.arn
      parameters = {
        tags = local.terraform_aws_github_runner_tags
      }
      housekeeper = {
        lambda = {
          artifact = {
            zip = "${data.external.download_lambdas.result.path}/runners.zip"
          }
        }
      }
    }

    observability = {
      logs = {
        level             = lower(var.runner_configs.log_level)
        retention_in_days = tonumber(var.runner_configs.logging_retention_in_days)
      }
    }

    compute_provider = {
      ec2 = {
        vpc_id     = var.network_configs.vpc_id
        subnet_ids = var.network_configs.subnet_ids
        runner_binaries = {
          syncer = {
            artifact = {
              zip = "${data.external.download_lambdas.result.path}/runner-binaries-syncer.zip"
            }
          }
        }
      }
    }

    multi_runner_config = local.multi_runner_config
  }
}
