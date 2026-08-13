mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test"
      user_id    = "AIDATEST"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }

  mock_data "aws_subnet" {
    defaults = {
      arn               = "arn:aws:ec2:eu-west-1:123456789012:subnet/subnet-test"
      availability_zone = "eu-west-1a"
      cidr_block        = "10.0.0.0/24"
      vpc_id            = "vpc-test"
    }
  }

  mock_data "aws_ssm_parameter" {
    defaults = {
      arn   = "arn:aws:ssm:eu-west-1:123456789012:parameter/test"
      name  = "/test"
      type  = "String"
      value = "ami-0123456789abcdef0"
    }
  }

  mock_data "aws_ami" {
    defaults = {
      architecture        = "x86_64"
      id                  = "ami-0123456789abcdef0"
      image_type          = "machine"
      name                = "forge-test-ami"
      root_device_name    = "/dev/xvda"
      root_device_type    = "ebs"
      virtualization_type = "hvm"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-runner"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/mock"
    }
  }

  mock_resource "aws_kms_key" {
    defaults = {
      arn    = "arn:aws:kms:eu-west-1:123456789012:key/00000000-0000-0000-0000-000000000000"
      key_id = "00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "aws_sqs_queue" {
    defaults = {
      arn = "arn:aws:sqs:eu-west-1:123456789012:mock"
      id  = "https://sqs.eu-west-1.amazonaws.com/123456789012/mock"
      url = "https://sqs.eu-west-1.amazonaws.com/123456789012/mock"
    }
  }
}

mock_provider "external" {
  mock_data "external" {
    defaults = {
      result = {
        path    = "/private/tmp/forge-test-lambda-cache"
        repo    = "github-aws-runners/terraform-aws-github-runner"
        version = "local-cache"
      }
    }
  }
}

mock_provider "archive" {}
mock_provider "local" {}
mock_provider "null" {}
mock_provider "random" {}

variables {
  aws_region = "eu-west-1"

  network_configs = {
    vpc_id            = "vpc-test"
    subnet_ids        = ["subnet-default"]
    lambda_vpc_id     = "vpc-test"
    lambda_subnet_ids = ["subnet-test"]
  }

  tenant_configs = {
    ecr_registries = ["123456789012.dkr.ecr.eu-west-1.amazonaws.com"]
    tags = {
      Environment = "test"
    }
  }

  runner_configs = {
    env                       = "test"
    prefix                    = "forge-test"
    ghes_url                  = ""
    log_level                 = "info"
    logging_retention_in_days = "3"
    github_app = {
      key_base64     = "dGVzdA=="
      id             = "12345"
      webhook_secret = "test"
    }
    runner_iam_role_managed_policy_arns = []
    runner_specs = {
      ec2 = {
        tags = { Scope = "entry" }
        runner = {
          os                     = "linux"
          architecture           = "x64"
          boot_time_in_minutes   = 7
          disable_default_labels = true
          extra_labels           = ["caller-extra"]
          group_name             = "Forge"
          name_prefix            = "forge-"
          run_as_root            = true
          run_as                 = "ec2-user"
          maximum_count          = 2
          ephemeral              = true
          jit_config_enabled     = false
          auto_update_disabled   = true
          tags                   = { Scope = "runner" }
          hooks = {
            job_started   = "echo caller-started\nexit 0"
            job_completed = "echo caller-completed"
          }
          iam = {
            managed_policy_arns = {
              caller = "arn:aws:iam::123456789012:policy/caller"
            }
            additional_trust_policy_json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
            path                         = "/forge/"
            permissions_boundary         = "arn:aws:iam::123456789012:policy/boundary"
          }
        }
        github = {
          organization_runners = true
        }
        lambda = {
          tags = { Scope = "lambda" }
        }
        queue = {
          delay_webhook_event            = 7
          job_queue_retention_in_seconds = 90000
          event_source_mapping = {
            batch_size                         = 5
            maximum_batching_window_in_seconds = 1
          }
          redrive_build_queue = {
            enabled         = true
            maxReceiveCount = 4
          }
          tags = { Scope = "queue" }
        }
        scale_up = {
          reserved_concurrent_executions = 2
          job_queued_check_enabled       = false
          tags                           = { Scope = "scale-up" }
        }
        scale_down = {
          schedule_expression             = "rate(10 minutes)"
          minimum_running_time_in_minutes = 5
          idle_config = [{
            cron             = "* * * * *"
            timeZone         = "Europe/Warsaw"
            idleCount        = 1
            evictionStrategy = "newest_first"
          }]
          tags = { Scope = "scale-down" }
        }
        pool = {
          config = [{
            schedule_expression          = "cron(0 8 * * ? *)"
            schedule_expression_timezone = "Europe/Warsaw"
            size                         = 1
          }]
          runner_owner = "cisco-open"
          tags         = { Scope = "pool" }
        }
        job_retry = {
          enabled          = true
          delay_in_seconds = 120
          delay_backoff    = 3
          max_attempts     = 2
          tags             = { Scope = "job-retry" }
          lambda = {
            memory_size                    = 512
            reserved_concurrent_executions = 3
            timeout                        = 45
          }
        }
        ssm = {
          tags = { Scope = "ssm" }
          parameters = {
            tags = { Scope = "ssm-parameters" }
          }
          housekeeper = {
            tags = { Scope = "ssm-housekeeper" }
          }
        }
        observability = {
          logs = {
            tags = { Scope = "logs" }
          }
        }
        compute_provider = {
          ec2 = {
            metadata_options = {
              http_endpoint               = "enabled"
              http_put_response_hop_limit = 2
              http_tokens                 = "optional"
              instance_metadata_tags      = "enabled"
            }
            ami = {
              filter = {
                name  = ["forge-*"]
                state = ["available"]
              }
              owners = ["123456789012"]
              kms_key = {
                arn = "arn:aws:kms:eu-west-1:123456789012:key/11111111-1111-1111-1111-111111111111"
              }
            }
            cloudwatch_agent = {
              enabled = true
              config  = "{\"agent\":{}}"
            }
            binaries_syncer = {
              enabled = false
            }
            detailed_monitoring_enabled   = true
            ebs_optimized                 = true
            instance_allocation_strategy  = "prioritized"
            instance_type_priorities      = { "m7i.large" = 1 }
            instance_types                = ["m7i.large"]
            instance_target_capacity_type = "on-demand"
            additional_security_group_ids = ["sg-runner"]
            scale_errors                  = ["InsufficientInstanceCapacity"]
            ssm_enabled                   = true
            subnet_ids                    = ["subnet-override"]
            tags                          = { Lane = "ec2" }
            user_data = {
              enabled               = true
              pre_install           = "caller-pre"
              post_install          = "caller-post"
              debug_logging_enabled = true
            }
            block_device_mappings = [{
              delete_on_termination = true
              device_name           = "/dev/xvda"
              encrypted             = true
              iops                  = 3000
              kms_key_id            = null
              snapshot_id           = null
              throughput            = 125
              volume_size           = 30
              volume_type           = "gp3"
            }]
          }
        }
        matcherConfig = {
          labelMatchers           = [["self-hosted", "ec2"], ["self-hosted", "gpu"]]
          exactMatch              = true
          bidirectionalLabelMatch = true
          priority                = 5
          enableDynamicLabels     = true
          awsDynamicLabelsPolicy = {
            blocked_keys = ["instance-type"]
          }
        }
      }
    }
  }
}

run "ec2_v2_input_plan" {
  command = plan

  plan_options {
    target = [
      data.aws_subnet.runner_subnet,
      module.runners.aws_sqs_queue.queued_builds,
    ]
  }

  assert {
    condition     = toset(keys(local.ec2_runner_configs)) == toset(["ec2"])
    error_message = "EC2 provider filtering must retain every EC2 lane."
  }

  assert {
    condition     = toset(keys(local.multi_runner_config_v2)) == toset(["ec2"])
    error_message = "The upstream v2 configuration must preserve every EC2 lane key."
  }

  assert {
    condition     = local.active_ec2_subnet_ids == toset(["subnet-override"])
    error_message = "EC2 effective subnet resolution must preserve per-lane overrides."
  }

  assert {
    condition = (
      tolist(local.multi_runner_config_v2.ec2.compute_provider.ec2.ami.filter.name) == tolist(["forge-*"])
      && local.multi_runner_config_v2.ec2.compute_provider.ec2.ami.id_ssm_parameter == null
      && local.multi_runner_config_v2.ec2.compute_provider.ec2.ami.kms_key.arn == "arn:aws:kms:eu-west-1:123456789012:key/11111111-1111-1111-1111-111111111111"
      && local.multi_runner_config_v2.ec2.compute_provider.ec2.ebs_optimized
    )
    error_message = "The v2 configuration must preserve nested EC2 AMI and fleet configuration."
  }

  assert {
    condition = (
      local.multi_runner_config_v2.ec2.compute_provider.ec2.metadata_options.http_tokens == "optional"
      && local.multi_runner_config_v2.ec2.compute_provider.ec2.metadata_options.http_put_response_hop_limit == 2
      && local.multi_runner_config_v2.ec2.compute_provider.ec2.cloudwatch_agent.enabled
      && local.multi_runner_config_v2.ec2.compute_provider.ec2.cloudwatch_agent.config == "{\"agent\":{}}"
      && !local.multi_runner_config_v2.ec2.compute_provider.ec2.binaries_syncer.enabled
      && local.multi_runner_config_v2.ec2.compute_provider.ec2.detailed_monitoring_enabled
      && local.multi_runner_config_v2.ec2.compute_provider.ec2.ssm_enabled
      && tolist(local.multi_runner_config_v2.ec2.compute_provider.ec2.additional_security_group_ids) == tolist(["sg-runner"])
    )
    error_message = "The v2 configuration must preserve nested EC2 bootstrap, metadata, and networking settings."
  }

  assert {
    condition = (
      local.multi_runner_config_v2.ec2.runner.boot_time_in_minutes == 7
      && local.multi_runner_config_v2.ec2.runner.disable_default_labels
      && tolist(local.multi_runner_config_v2.ec2.runner.extra_labels) == tolist(["caller-extra"])
      && local.multi_runner_config_v2.ec2.runner.group_name == "Forge"
      && local.multi_runner_config_v2.ec2.runner.name_prefix == "forge-"
      && local.multi_runner_config_v2.ec2.runner.run_as_root
      && local.multi_runner_config_v2.ec2.runner.run_as == "ec2-user"
      && local.multi_runner_config_v2.ec2.runner.maximum_count == 2
      && local.multi_runner_config_v2.ec2.runner.ephemeral
      && !local.multi_runner_config_v2.ec2.runner.jit_config_enabled
      && local.multi_runner_config_v2.ec2.runner.auto_update_disabled
      && local.multi_runner_config_v2.ec2.github.organization_runners
    )
    error_message = "The v2 configuration must preserve the complete nested runner and GitHub blocks."
  }

  assert {
    condition = (
      local.multi_runner_config_v2.ec2.queue.delay_webhook_event == 7
      && local.multi_runner_config_v2.ec2.queue.job_queue_retention_in_seconds == 90000
      && local.multi_runner_config_v2.ec2.queue.event_source_mapping.batch_size == 5
      && local.multi_runner_config_v2.ec2.queue.event_source_mapping.maximum_batching_window_in_seconds == 1
      && local.multi_runner_config_v2.ec2.scale_up.reserved_concurrent_executions == 2
      && !local.multi_runner_config_v2.ec2.scale_up.job_queued_check_enabled
      && local.multi_runner_config_v2.ec2.scale_down.schedule_expression == "rate(10 minutes)"
      && local.multi_runner_config_v2.ec2.scale_down.minimum_running_time_in_minutes == 5
      && local.multi_runner_config_v2.ec2.scale_down.idle_config[0].idleCount == 1
      && local.multi_runner_config_v2.ec2.queue.redrive_build_queue.maxReceiveCount == 4
    )
    error_message = "The v2 configuration must preserve the queue, scale-up, and scale-down blocks."
  }

  assert {
    condition = (
      local.multi_runner_config_v2.ec2.pool.config[0].size == 1
      && local.multi_runner_config_v2.ec2.pool.runner_owner == "cisco-open"
      && local.multi_runner_config_v2.ec2.job_retry.enabled
      && local.multi_runner_config_v2.ec2.job_retry.delay_in_seconds == 120
      && local.multi_runner_config_v2.ec2.job_retry.delay_backoff == 3
      && local.multi_runner_config_v2.ec2.job_retry.max_attempts == 2
      && local.multi_runner_config_v2.ec2.job_retry.lambda.memory_size == 512
      && local.multi_runner_config_v2.ec2.job_retry.lambda.reserved_concurrent_executions == 3
      && local.multi_runner_config_v2.ec2.job_retry.lambda.timeout == 45
    )
    error_message = "The v2 configuration must preserve the pool and job-retry blocks."
  }

  assert {
    condition = (
      local.multi_runner_config_v2.ec2.compute_provider.ec2.user_data.pre_install == "caller-pre"
      && startswith(local.multi_runner_config_v2.ec2.compute_provider.ec2.user_data.post_install, "caller-post\n")
      && strcontains(local.multi_runner_config_v2.ec2.compute_provider.ec2.user_data.post_install, "su -l root -c")
      && strcontains(local.multi_runner_config_v2.ec2.compute_provider.ec2.user_data.post_install, "--config /root/.docker")
      && local.multi_runner_config_v2.ec2.compute_provider.ec2.user_data.debug_logging_enabled
      && length(local.multi_runner_config_v2.ec2.compute_provider.ec2.log_files) == 4
      && local.multi_runner_config_v2.ec2.compute_provider.ec2.log_files[3].file_path == "/root/hook.log"
      && local.multi_runner_config_v2.ec2.compute_provider.ec2.tags.Environment == "test"
      && local.multi_runner_config_v2.ec2.compute_provider.ec2.tags.Lane == "ec2"
    )
    error_message = "The v2 configuration must retain Forge user-data, logging, and tag overlays."
  }

  assert {
    condition = (
      tolist(local.ec2_default_ami_filters.ec2.name) == tolist(["al2023-ami-2023.*-kernel-6.*-x86_64"])
      && tolist(local.ec2_compute_provider.ec2.ami.filter.name) == tolist(["forge-*"])
      && tolist(local.ec2_compute_provider.ec2.ami.filter.state) == tolist(["available"])
    )
    error_message = "The scheduled AMI refresh must merge upstream defaults with caller filters."
  }

  assert {
    condition = (
      startswith(
        local.multi_runner_config_v2.ec2.runner.hooks.job_started,
        "printf '%s' '${base64encode("echo caller-started\nexit 0")}' | base64 --decode | bash\n",
      )
      && startswith(
        local.multi_runner_config_v2.ec2.runner.hooks.job_completed,
        "printf '%s' '${base64encode("echo caller-completed")}' | base64 --decode | bash\n",
      )
      && local.multi_runner_config_v2.ec2.runner.iam.managed_policy_arns.caller == "arn:aws:iam::123456789012:policy/caller"
      && local.multi_runner_config_v2.ec2.runner.iam.managed_policy_arns.forge_ec2_tags == "arn:aws:iam::123456789012:policy/mock"
      && local.multi_runner_config_v2.ec2.runner.iam.managed_policy_arns.forge_runner_hooks_ssm_read == "arn:aws:iam::123456789012:policy/mock"
    )
    error_message = "Caller hooks must be isolated from Forge's required lifecycle hooks, and Forge policies must augment caller policies."
  }

  assert {
    condition = (
      length(local.multi_runner_config_v2.ec2.matcherConfig.labelMatchers) == 2
      && tolist(local.multi_runner_config_v2.ec2.matcherConfig.labelMatchers[0]) == tolist(["self-hosted", "ec2"])
      && tolist(local.multi_runner_config_v2.ec2.matcherConfig.labelMatchers[1]) == tolist(["self-hosted", "gpu"])
      && local.multi_runner_config_v2.ec2.matcherConfig.exactMatch
      && local.multi_runner_config_v2.ec2.matcherConfig.bidirectionalLabelMatch
      && local.multi_runner_config_v2.ec2.matcherConfig.priority == 5
      && local.multi_runner_config_v2.ec2.matcherConfig.enableDynamicLabels
      && tolist(local.multi_runner_config_v2.ec2.matcherConfig.awsDynamicLabelsPolicy.blocked_keys) == tolist(["instance-type"])
    )
    error_message = "The v2 configuration must preserve matcher configuration."
  }

  assert {
    condition = (
      local.multi_runner_config_v2.ec2.tags.Scope == "entry"
      && local.multi_runner_config_v2.ec2.runner.tags.Scope == "runner"
      && local.multi_runner_config_v2.ec2.lambda.tags.Scope == "lambda"
      && local.multi_runner_config_v2.ec2.queue.tags.Scope == "queue"
      && local.multi_runner_config_v2.ec2.scale_up.tags.Scope == "scale-up"
      && local.multi_runner_config_v2.ec2.scale_down.tags.Scope == "scale-down"
      && local.multi_runner_config_v2.ec2.pool.tags.Scope == "pool"
      && local.multi_runner_config_v2.ec2.job_retry.tags.Scope == "job-retry"
      && local.multi_runner_config_v2.ec2.ssm.tags.Scope == "ssm"
      && local.multi_runner_config_v2.ec2.ssm.parameters.tags.Scope == "ssm-parameters"
      && local.multi_runner_config_v2.ec2.ssm.housekeeper.tags.Scope == "ssm-housekeeper"
      && local.multi_runner_config_v2.ec2.observability.logs.tags.Scope == "logs"
    )
    error_message = "The v2 configuration must preserve every component tag scope."
  }

  assert {
    condition = (
      local.multi_runner_config_v2.ec2.runner.iam.additional_trust_policy_json == "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
      && local.multi_runner_config_v2.ec2.runner.iam.path == "/forge/"
      && local.multi_runner_config_v2.ec2.runner.iam.permissions_boundary == "arn:aws:iam::123456789012:policy/boundary"
      && local.multi_runner_config_v2.ec2.ssm.kms_key.arn == "arn:aws:kms:eu-west-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    )
    error_message = "The v2 configuration must preserve IAM ownership settings and default SSM encryption to Forge's KMS key."
  }

}
