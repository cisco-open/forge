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
            ami = {
              filter = {
                name  = ["forge-*"]
                state = ["available"]
              }
              owners = ["123456789012"]
            }
            ebs_optimized                 = true
            instance_types                = ["m7i.large"]
            instance_target_capacity_type = "on-demand"
            subnet_ids                    = ["subnet-override"]
            user_data = {
              enabled = true
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

run "ec2_v2_plan" {
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
    error_message = "The upstream v2 map must preserve every EC2 lane key."
  }

  assert {
    condition     = local.active_ec2_subnet_ids == toset(["subnet-override"])
    error_message = "EC2 effective subnet resolution must preserve per-lane overrides."
  }

  assert {
    condition = (
      local.multi_runner_config_v2.ec2.compute_provider.ec2 != null
      && tolist(local.multi_runner_config_v2.ec2.compute_provider.ec2.ami.filter.name) == tolist(["forge-*"])
      && local.multi_runner_config_v2.ec2.compute_provider.ec2.ami.id_ssm_parameter == null
      && local.multi_runner_config_v2.ec2.compute_provider.ec2.ebs_optimized
    )
    error_message = "The v2 translation must preserve the nested EC2 provider configuration."
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
      length(local.multi_runner_config_v2.ec2.matcherConfig.labelMatchers) == 1
      && tolist(local.multi_runner_config_v2.ec2.matcherConfig.labelMatchers[0]) == tolist(["self-hosted", "ec2"])
    )
    error_message = "Empty extra labels must retain the base label matcher."
  }
}
