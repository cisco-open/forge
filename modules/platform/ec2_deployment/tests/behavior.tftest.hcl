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
    ecr_registries = []
    tags = {
      Environment = "test"
    }
  }

  runner_configs = {
    env                       = "test"
    prefix                    = "forge-test"
    ghes_url                  = ""
    ghes_org                  = "cisco-open"
    log_level                 = "info"
    logging_retention_in_days = "3"
    github_app = {
      key_base64     = "dGVzdA=="
      id             = "12345"
      webhook_secret = "test"
    }
    runner_iam_role_managed_policy_arns = []
    runner_group_name                   = "Default"
    runner_specs = {
      ec2 = {
        runner_labels       = ["self-hosted", "ec2"]
        runner_os           = "linux"
        runner_architecture = "x64"
        extra_labels        = []
        max_instances       = 2
        min_run_time        = 5
        pool_config         = []
        runner_user         = "ec2-user"
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
              enabled      = true
              pre_install  = "caller-pre"
              post_install = "caller-post"
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
  }
}

run "ec2_v2_input_v1_adapter_plan" {
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
    condition     = toset(keys(local.multi_runner_config_v1)) == toset(["ec2"])
    error_message = "The stable v1 adapter must preserve every EC2 lane key."
  }

  assert {
    condition     = local.active_ec2_subnet_ids == toset(["subnet-override"])
    error_message = "EC2 effective subnet resolution must preserve per-lane overrides."
  }

  assert {
    condition = (
      tolist(local.multi_runner_config_v1.ec2.runner_config.ami.filter.name) == tolist(["forge-*"])
      && local.multi_runner_config_v1.ec2.runner_config.ami.id_ssm_parameter_arn == null
      && local.multi_runner_config_v1.ec2.runner_config.ami.kms_key_arn == "arn:aws:kms:eu-west-1:123456789012:key/11111111-1111-1111-1111-111111111111"
      && local.multi_runner_config_v1.ec2.runner_config.ebs_optimized
    )
    error_message = "The v1 adapter must flatten the nested EC2 AMI and fleet configuration."
  }

  assert {
    condition = (
      local.multi_runner_config_v1.ec2.runner_config.runner_metadata_options.http_tokens == "optional"
      && local.multi_runner_config_v1.ec2.runner_config.runner_metadata_options.http_put_response_hop_limit == 2
      && local.multi_runner_config_v1.ec2.runner_config.enable_cloudwatch_agent
      && local.multi_runner_config_v1.ec2.runner_config.cloudwatch_config == "{\"agent\":{}}"
      && !local.multi_runner_config_v1.ec2.runner_config.enable_runner_binaries_syncer
      && local.multi_runner_config_v1.ec2.runner_config.enable_runner_detailed_monitoring
      && local.multi_runner_config_v1.ec2.runner_config.enable_ssm_on_runners
      && tolist(local.multi_runner_config_v1.ec2.runner_config.runner_additional_security_group_ids) == tolist(["sg-runner"])
    )
    error_message = "The v1 adapter must preserve nested EC2 bootstrap, metadata, and networking settings."
  }

  assert {
    condition = (
      local.multi_runner_config_v1.ec2.runner_config.userdata_pre_install == "caller-pre"
      && startswith(local.multi_runner_config_v1.ec2.runner_config.userdata_post_install, "caller-post\n")
      && length(local.multi_runner_config_v1.ec2.runner_config.runner_log_files) == 4
      && local.multi_runner_config_v1.ec2.runner_config.runner_ec2_tags.Environment == "test"
      && local.multi_runner_config_v1.ec2.runner_config.runner_ec2_tags.Lane == "ec2"
    )
    error_message = "The v1 adapter must retain Forge user-data, logging, and tag overlays."
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
      length(local.multi_runner_config_v1.ec2.matcherConfig.labelMatchers) == 1
      && tolist(local.multi_runner_config_v1.ec2.matcherConfig.labelMatchers[0]) == tolist(["self-hosted", "ec2"])
    )
    error_message = "Empty extra labels must retain the base label matcher."
  }
}
