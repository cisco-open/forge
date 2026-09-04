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
          disable_default_labels = true
          extra_labels           = ["caller-extra"]
          group_name             = "Forge"
          name_prefix            = "forge-"
          run_as_root            = true
          run_as                 = "ec2-user"
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
        lambda = {
          runtime            = "nodejs22.x"
          architecture       = "x86_64"
          subnet_ids         = ["subnet-lambda-override"]
          security_group_ids = ["sg-lambda"]
          tags               = { Scope = "lambda" }
          role = {
            path                 = "/lambda/"
            permissions_boundary = "arn:aws:iam::123456789012:policy/lambda-boundary"
          }
        }

        orchestration_provider = {
          webhook = {
            runner = {
              boot_time_in_minutes = 7
              ephemeral            = true
              jit_config_enabled   = false
              maximum_count        = 2
            }
            github = {
              organization_runners = true
            }
            lambda = {
              scale = {
                up = {
                  memory_size                    = 768
                  timeout                        = 40
                  reserved_concurrent_executions = 2
                  job_queued_check_enabled       = false
                  event_source_mapping = {
                    batch_size                         = 5
                    maximum_batching_window_in_seconds = 1
                  }
                  tags = { Scope = "scale-up" }
                }
                down = {
                  memory_size                     = 1024
                  timeout                         = 90
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
              }
              pool = {
                memory_size                    = 512
                timeout                        = 75
                reserved_concurrent_executions = 2
                config = [{
                  schedule_expression          = "cron(0 8 * * ? *)"
                  schedule_expression_timezone = "Europe/Warsaw"
                  size                         = 1
                }]
                include_busy_runners = false
                runner_owner         = "cisco-open"
                tags                 = { Scope = "pool" }
              }
            }
            queue = {
              delay_webhook_event            = 7
              job_queue_retention_in_seconds = 90000
              visibility_timeout_seconds     = 240
              redrive_build_queue = {
                enabled         = true
                maxReceiveCount = 4
              }
              tags = { Scope = "queue" }
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
        ssm = {
          tags = { Scope = "ssm" }
          paths = {
            root   = "/custom-root"
            tokens = "custom-tokens"
            config = "custom-config"
          }
          parameters = {
            tags = { Scope = "ssm-parameters" }
          }
          housekeeper = {
            schedule_expression = "rate(12 hours)"
            state               = "DISABLED"
            tags                = { Scope = "ssm-housekeeper" }
            lambda = {
              artifact = {
                zip = "/private/tmp/forge-test-lambda-cache/ssm-housekeeper.zip"
              }
              memory_size = 384
              timeout     = 70
            }
            config = {
              tokenPath      = "custom-token-path"
              minimumDaysOld = 2
              dryRun         = true
            }
          }
        }
        observability = {
          logs = {
            level             = "debug"
            retention_in_days = 14
            kms_key_id        = "arn:aws:kms:eu-west-1:123456789012:key/22222222-2222-2222-2222-222222222222"
            class             = "INFREQUENT_ACCESS"
            tags              = { Scope = "logs" }
          }
          tracing = {
            mode                  = "Active"
            capture_http_requests = false
            capture_error         = false
          }
          metrics = {
            enable    = false
            namespace = "Forge/Test"
            metric = {
              enable_github_app_rate_limit = false
              enable_job_retry             = true
            }
          }
        }
        compute_provider = {
          aws = {
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
              detailed_monitoring_enabled    = true
              ebs_optimized                  = true
              instance_allocation_strategy   = "prioritized"
              instance_type_priorities       = { "m7i.large" = 1 }
              instance_types                 = ["m7i.large"]
              instance_target_capacity_type  = "on-demand"
              additional_security_group_ids  = ["sg-runner"]
              managed_security_group_enabled = false
              egress_rules = [{
                cidr_blocks      = ["10.0.0.0/8"]
                ipv6_cidr_blocks = []
                prefix_list_ids  = []
                from_port        = 443
                protocol         = "tcp"
                security_groups  = []
                self             = false
                to_port          = 443
                description      = "HTTPS"
              }]
              instance_profile_path         = "/runner/"
              key_name                      = "forge-test"
              associate_public_ipv4_address = false
              scale_errors                  = ["InsufficientInstanceCapacity"]
              ssm_enabled                   = true
              subnet_ids                    = ["subnet-override"]
              tags                          = { Configuration = "ec2" }
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
        }
      }
      default_path = {
        runner = {
          os           = "linux"
          architecture = "x64"
        }
        orchestration_provider = {
          webhook = {
            runner = {
              maximum_count = 1
            }
            matcherConfig = {
              labelMatchers = [["self-hosted", "default-path"]]
            }
          }
        }
        compute_provider = {
          aws = {
            ec2 = {
              ami            = {}
              instance_types = ["m7i.large"]
              binaries_syncer = {
                enabled = false
              }
            }
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
    condition     = toset(keys(local.ec2_runner_configs)) == toset(["default_path", "ec2"])
    error_message = "EC2 provider filtering must retain every EC2 runner configuration."
  }

  assert {
    condition     = toset(keys(local.multi_runner_config)) == toset(["default_path", "ec2"])
    error_message = "The upstream v2 configuration must preserve every EC2 runner-configuration key."
  }

  assert {
    condition = (
      toset(keys(local.multi_runner_config.ec2.compute_provider)) == toset(["aws"])
      && toset(keys(local.multi_runner_config.ec2.compute_provider.aws)) == toset(["ec2"])
    )
    error_message = "Forge must preserve the AWS namespace while keeping ec2 as the runtime compute-provider type."
  }

  assert {
    condition = alltrue([
      for runner_config in values(local.multi_runner_config) :
      length([
        for provider_config in values(runner_config.orchestration_provider) : provider_config
        if provider_config != null
      ]) == 1
    ])
    error_message = "Every normalized runner configuration must retain exactly one orchestration provider."
  }

  assert {
    condition     = local.active_ec2_subnet_ids == toset(["subnet-default", "subnet-override"])
    error_message = "EC2 effective subnet resolution must preserve per-configuration overrides."
  }

  assert {
    condition = (
      tolist(local.multi_runner_config.ec2.compute_provider.aws.ec2.ami.filter.name) == tolist(["forge-*"])
      && local.multi_runner_config.ec2.compute_provider.aws.ec2.ami.id_ssm_parameter == null
      && local.multi_runner_config.ec2.compute_provider.aws.ec2.ami.kms_key.arn == "arn:aws:kms:eu-west-1:123456789012:key/11111111-1111-1111-1111-111111111111"
      && local.multi_runner_config.ec2.compute_provider.aws.ec2.ebs_optimized
    )
    error_message = "The v2 configuration must preserve nested EC2 AMI and fleet configuration."
  }

  assert {
    condition = (
      local.multi_runner_config.ec2.compute_provider.aws.ec2.metadata_options.http_tokens == "optional"
      && local.multi_runner_config.ec2.compute_provider.aws.ec2.metadata_options.http_put_response_hop_limit == 2
      && local.multi_runner_config.ec2.compute_provider.aws.ec2.cloudwatch_agent.enabled
      && local.multi_runner_config.ec2.compute_provider.aws.ec2.cloudwatch_agent.config == "{\"agent\":{}}"
      && !local.multi_runner_config.ec2.compute_provider.aws.ec2.binaries_syncer.enabled
      && local.multi_runner_config.ec2.compute_provider.aws.ec2.detailed_monitoring_enabled
      && local.multi_runner_config.ec2.compute_provider.aws.ec2.ssm_enabled
      && tolist(local.multi_runner_config.ec2.compute_provider.aws.ec2.additional_security_group_ids) == tolist(["sg-runner"])
      && !local.multi_runner_config.ec2.compute_provider.aws.ec2.managed_security_group_enabled
      && local.multi_runner_config.ec2.compute_provider.aws.ec2.egress_rules[0].description == "HTTPS"
      && local.multi_runner_config.ec2.compute_provider.aws.ec2.instance_profile_path == "/runner/"
      && local.multi_runner_config.ec2.compute_provider.aws.ec2.key_name == "forge-test"
      && !local.multi_runner_config.ec2.compute_provider.aws.ec2.associate_public_ipv4_address
    )
    error_message = "The v2 configuration must preserve nested EC2 bootstrap, metadata, and networking settings."
  }

  assert {
    condition = (
      local.multi_runner_config.ec2.runner.disable_default_labels
      && tolist(local.multi_runner_config.ec2.runner.extra_labels) == tolist(["caller-extra"])
      && local.multi_runner_config.ec2.runner.group_name == "Forge"
      && local.multi_runner_config.ec2.runner.name_prefix == "forge-"
      && local.multi_runner_config.ec2.runner.run_as_root
      && local.multi_runner_config.ec2.runner.run_as == "ec2-user"
      && local.multi_runner_config.ec2.orchestration_provider.webhook.runner.boot_time_in_minutes == 7
      && local.multi_runner_config.ec2.orchestration_provider.webhook.runner.ephemeral
      && !local.multi_runner_config.ec2.orchestration_provider.webhook.runner.jit_config_enabled
      && local.multi_runner_config.ec2.orchestration_provider.webhook.runner.maximum_count == 2
      && local.multi_runner_config.ec2.runner.auto_update_disabled
      && local.multi_runner_config.ec2.orchestration_provider.webhook.github.organization_runners
    )
    error_message = "The v2 configuration must preserve the common runner and webhook-owned runner and GitHub blocks."
  }

  assert {
    condition = (
      local.multi_runner_config.ec2.orchestration_provider.webhook.queue.delay_webhook_event == 7
      && local.multi_runner_config.ec2.orchestration_provider.webhook.queue.job_queue_retention_in_seconds == 90000
      && local.multi_runner_config.ec2.orchestration_provider.webhook.queue.visibility_timeout_seconds == 240
      && local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.scale.up.event_source_mapping.batch_size == 5
      && local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.scale.up.event_source_mapping.maximum_batching_window_in_seconds == 1
      && local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.scale.up.memory_size == 768
      && local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.scale.up.timeout == 40
      && local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.scale.up.reserved_concurrent_executions == 2
      && !local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.scale.up.job_queued_check_enabled
      && local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.scale.down.memory_size == 1024
      && local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.scale.down.timeout == 90
      && local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.scale.down.schedule_expression == "rate(10 minutes)"
      && local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.scale.down.minimum_running_time_in_minutes == 5
      && local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.scale.down.idle_config[0].idleCount == 1
      && local.multi_runner_config.ec2.orchestration_provider.webhook.queue.redrive_build_queue.maxReceiveCount == 4
    )
    error_message = "The v2 configuration must preserve the queue, scale-up, and scale-down blocks."
  }

  assert {
    condition = (
      local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.pool.config[0].size == 1
      && local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.pool.memory_size == 512
      && local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.pool.timeout == 75
      && local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.pool.reserved_concurrent_executions == 2
      && !local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.pool.include_busy_runners
      && local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.pool.runner_owner == "cisco-open"
      && local.multi_runner_config.ec2.orchestration_provider.webhook.job_retry.enabled
      && local.multi_runner_config.ec2.orchestration_provider.webhook.job_retry.delay_in_seconds == 120
      && local.multi_runner_config.ec2.orchestration_provider.webhook.job_retry.delay_backoff == 3
      && local.multi_runner_config.ec2.orchestration_provider.webhook.job_retry.max_attempts == 2
      && local.multi_runner_config.ec2.orchestration_provider.webhook.job_retry.lambda.memory_size == 512
      && local.multi_runner_config.ec2.orchestration_provider.webhook.job_retry.lambda.reserved_concurrent_executions == 3
      && local.multi_runner_config.ec2.orchestration_provider.webhook.job_retry.lambda.timeout == 45
    )
    error_message = "The v2 configuration must preserve the pool and job-retry blocks."
  }

  assert {
    condition     = !can(local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.artifact)
    error_message = "Runner-control artifacts must be configured globally, not in a per-runner webhook Lambda block."
  }

  assert {
    condition = (
      local.multi_runner_config.ec2.compute_provider.aws.ec2.user_data.pre_install == "caller-pre"
      && startswith(local.multi_runner_config.ec2.compute_provider.aws.ec2.user_data.post_install, "caller-post\n")
      && strcontains(local.multi_runner_config.ec2.compute_provider.aws.ec2.user_data.post_install, "su -l root -c")
      && strcontains(local.multi_runner_config.ec2.compute_provider.aws.ec2.user_data.post_install, "--config /root/.docker")
      && local.multi_runner_config.ec2.compute_provider.aws.ec2.user_data.debug_logging_enabled
      && length(local.multi_runner_config.ec2.compute_provider.aws.ec2.log_files) == 4
      && local.multi_runner_config.ec2.compute_provider.aws.ec2.log_files[3].file_path == "/root/hook.log"
      && local.multi_runner_config.ec2.compute_provider.aws.ec2.tags.Environment == "test"
      && local.multi_runner_config.ec2.compute_provider.aws.ec2.tags.Configuration == "ec2"
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
        local.multi_runner_config.ec2.runner.hooks.job_started,
        "printf '%s' '${base64encode("echo caller-started\nexit 0")}' | base64 --decode | bash\n",
      )
      && startswith(
        local.multi_runner_config.ec2.runner.hooks.job_completed,
        "printf '%s' '${base64encode("echo caller-completed")}' | base64 --decode | bash\n",
      )
      && local.multi_runner_config.ec2.runner.iam.managed_policy_arns.caller == "arn:aws:iam::123456789012:policy/caller"
      && local.multi_runner_config.ec2.runner.iam.managed_policy_arns.forge_ec2_tags == "arn:aws:iam::123456789012:policy/mock"
      && local.multi_runner_config.ec2.runner.iam.managed_policy_arns.forge_runner_hooks_ssm_read == "arn:aws:iam::123456789012:policy/mock"
    )
    error_message = "Caller hooks must be isolated from Forge's required lifecycle hooks, and Forge policies must augment caller policies."
  }

  assert {
    condition = (
      length(local.multi_runner_config.ec2.orchestration_provider.webhook.matcherConfig.labelMatchers) == 2
      && tolist(local.multi_runner_config.ec2.orchestration_provider.webhook.matcherConfig.labelMatchers[0]) == tolist(["self-hosted", "ec2"])
      && tolist(local.multi_runner_config.ec2.orchestration_provider.webhook.matcherConfig.labelMatchers[1]) == tolist(["self-hosted", "gpu"])
      && local.multi_runner_config.ec2.orchestration_provider.webhook.matcherConfig.exactMatch
      && local.multi_runner_config.ec2.orchestration_provider.webhook.matcherConfig.bidirectionalLabelMatch
      && local.multi_runner_config.ec2.orchestration_provider.webhook.matcherConfig.priority == 5
      && local.multi_runner_config.ec2.orchestration_provider.webhook.matcherConfig.enableDynamicLabels
      && local.multi_runner_config.ec2.orchestration_provider.webhook.matcherConfig.dynamic_labels_enabled
      && tolist(local.multi_runner_config.ec2.orchestration_provider.webhook.matcherConfig.awsDynamicLabelsPolicy.blocked_keys) == tolist(["instance-type"])
    )
    error_message = "The v2 configuration must preserve matcher configuration."
  }

  assert {
    condition = (
      local.multi_runner_config.ec2.tags.Scope == "entry"
      && local.multi_runner_config.ec2.runner.tags.Scope == "runner"
      && local.multi_runner_config.ec2.lambda.tags.Scope == "lambda"
      && local.multi_runner_config.ec2.orchestration_provider.webhook.queue.tags.Scope == "queue"
      && local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.scale.up.tags.Scope == "scale-up"
      && local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.scale.down.tags.Scope == "scale-down"
      && local.multi_runner_config.ec2.orchestration_provider.webhook.lambda.pool.tags.Scope == "pool"
      && local.multi_runner_config.ec2.orchestration_provider.webhook.job_retry.tags.Scope == "job-retry"
      && local.multi_runner_config.ec2.ssm.tags.Scope == "ssm"
      && local.multi_runner_config.ec2.ssm.parameters.tags.Scope == "ssm-parameters"
      && local.multi_runner_config.ec2.ssm.housekeeper.tags.Scope == "ssm-housekeeper"
      && local.multi_runner_config.ec2.observability.logs.tags.Scope == "logs"
    )
    error_message = "The v2 configuration must preserve every component tag scope."
  }

  assert {
    condition = (
      local.multi_runner_config.ec2.runner.iam.additional_trust_policy_json == "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
      && local.multi_runner_config.ec2.runner.iam.path == "/forge/"
      && local.multi_runner_config.ec2.runner.iam.permissions_boundary == "arn:aws:iam::123456789012:policy/boundary"
    )
    error_message = "The v2 configuration must preserve runner-configuration IAM ownership settings."
  }

  assert {
    condition = (
      local.multi_runner_config.ec2.lambda.runtime == "nodejs22.x"
      && local.multi_runner_config.ec2.lambda.architecture == "x86_64"
      && tolist(local.multi_runner_config.ec2.lambda.subnet_ids) == tolist(["subnet-lambda-override"])
      && tolist(local.multi_runner_config.ec2.lambda.security_group_ids) == tolist(["sg-lambda"])
      && local.multi_runner_config.ec2.lambda.role.path == "/lambda/"
      && local.multi_runner_config.ec2.lambda.role.permissions_boundary == "arn:aws:iam::123456789012:policy/lambda-boundary"
    )
    error_message = "The v2 configuration must preserve runner-configuration Lambda runtime, network, and role overrides."
  }

  assert {
    condition = (
      local.multi_runner_config.ec2.ssm.paths.root == "/custom-root"
      && local.multi_runner_config.ec2.ssm.paths.tokens == "custom-tokens"
      && local.multi_runner_config.ec2.ssm.paths.config == "custom-config"
      && local.multi_runner_config.ec2.ssm.housekeeper.schedule_expression == "rate(12 hours)"
      && local.multi_runner_config.ec2.ssm.housekeeper.state == "DISABLED"
      && local.multi_runner_config.ec2.ssm.housekeeper.lambda.artifact.zip == "/private/tmp/forge-test-lambda-cache/ssm-housekeeper.zip"
      && local.multi_runner_config.ec2.ssm.housekeeper.lambda.memory_size == 384
      && local.multi_runner_config.ec2.ssm.housekeeper.lambda.timeout == 70
      && local.multi_runner_config.ec2.ssm.housekeeper.config.tokenPath == "custom-token-path"
      && local.multi_runner_config.ec2.ssm.housekeeper.config.minimumDaysOld == 2
      && local.multi_runner_config.ec2.ssm.housekeeper.config.dryRun
    )
    error_message = "The v2 configuration must preserve runner-configuration SSM paths and housekeeper overrides."
  }

  assert {
    condition = (
      local.multi_runner_config.ec2.observability.logs.level == "debug"
      && local.multi_runner_config.ec2.observability.logs.retention_in_days == 14
      && local.multi_runner_config.ec2.observability.logs.kms_key_id == "arn:aws:kms:eu-west-1:123456789012:key/22222222-2222-2222-2222-222222222222"
      && local.multi_runner_config.ec2.observability.logs.class == "INFREQUENT_ACCESS"
      && local.multi_runner_config.ec2.observability.tracing.mode == "Active"
      && !local.multi_runner_config.ec2.observability.tracing.capture_http_requests
      && !local.multi_runner_config.ec2.observability.tracing.capture_error
      && !local.multi_runner_config.ec2.observability.metrics.enable
      && !local.multi_runner_config.ec2.observability.metrics.enabled
      && local.multi_runner_config.ec2.observability.metrics.namespace == "Forge/Test"
      && !local.multi_runner_config.ec2.observability.metrics.metric.enable_github_app_rate_limit
      && !local.multi_runner_config.ec2.observability.metrics.metric.github_app_rate_limit.enabled
      && local.multi_runner_config.ec2.observability.metrics.metric.enable_job_retry
      && local.multi_runner_config.ec2.observability.metrics.metric.job_retry.enabled
    )
    error_message = "The v2 configuration must preserve runner-configuration observability overrides."
  }

  assert {
    condition = (
      local.experimental_config.github.app.id == "12345"
      && local.experimental_config.github.enterprise_server.url == null
      && local.experimental_config.orchestration_provider.webhook.eventbridge.enabled
      && local.experimental_config.orchestration_provider.webhook.lambda.artifact.zip == "/private/tmp/forge-test-lambda-cache/runners.zip"
      && tolist(local.experimental_config.lambda.subnet_ids) == tolist(["subnet-test"])
      && length(local.experimental_config.lambda.security_group_ids) == 1
      && local.experimental_config.orchestration_provider.webhook.lambda.webhook.artifact.zip == "/private/tmp/forge-test-lambda-cache/webhook.zip"
      && local.experimental_config.ssm.kms_key_id == "arn:aws:kms:eu-west-1:123456789012:key/00000000-0000-0000-0000-000000000000"
      && local.experimental_config.ssm.housekeeper.lambda.artifact.zip == "/private/tmp/forge-test-lambda-cache/runners.zip"
      && local.experimental_config.observability.logs.level == "info"
      && local.experimental_config.observability.logs.retention_in_days == 3
      && local.experimental_config.compute_provider.aws.ec2.vpc_id == "vpc-test"
      && tolist(local.experimental_config.compute_provider.aws.ec2.subnet_ids) == tolist(["subnet-default"])
      && local.experimental_config.compute_provider.aws.ec2.runner_binaries.syncer.artifact.zip == "/private/tmp/forge-test-lambda-cache/runner-binaries-syncer.zip"
      && local.experimental_config.multi_runner_config == local.multi_runner_config
    )
    error_message = "Forge must populate the authoritative global experimental contract."
  }

  assert {
    condition = (
      local.experimental_config.tags == local.terraform_aws_github_runner_tags
      && local.experimental_config.lambda.tags == local.terraform_aws_github_runner_tags
      && local.experimental_config.ssm.parameters.tags == local.terraform_aws_github_runner_tags
    )
    error_message = "Forge resource tags must be carried by the experimental global, Lambda, and Parameter Store tag maps."
  }

  assert {
    condition = (
      local.experimental_config.orchestration_provider.webhook.lambda.webhook.api_gateway_access_log_settings.destination_arn == aws_cloudwatch_log_group.webhook_api_gateway_access.arn
      && local.experimental_config.orchestration_provider.webhook.lambda.webhook.api_gateway_access_log_settings.format == local.webhook_api_gateway_access_log_format
    )
    error_message = "Forge webhook API Gateway access-log settings must be carried by the experimental webhook contract."
  }

}
