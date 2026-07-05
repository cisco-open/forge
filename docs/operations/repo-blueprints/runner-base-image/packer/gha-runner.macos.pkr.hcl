packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "1.8.1"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "1.1.4"
    }
  }
}

variable "aws_region" {
  default = env("AWS_REGION")
}

variable "vpc_id" {
  default = env("PACKER_VPC_ID")
}

variable "subnet_id" {
  default = env("PACKER_SUBNET_ID")
}

variable "availability_zone" {
  default = env("PACKER_AVAILABILITY_ZONE")
}

variable "license_configuration_arn" {
  default = env("PACKER_LICENSE_CONFIGURATION_ARN")
}

variable "host_resource_group_arn" {
  default = env("PACKER_HOST_RESOURCE_GROUP_ARN")
}

variable "builder_allowed_cidr" {
  default = env("PACKER_ALLOWED_CIDR")
}

variable "version" {
  default = env("VERSION")
}

variable "job_id" {
  default = env("JOB_ID")
}

variable "branch" {
  default = env("BRANCH")
}

variable "arch" {
  default = env("AMI_ARCH")
}

variable "macos_major_version" {
  default = env("MACOS_MAJOR_VERSION")
}

variable "gh_pat" {
  sensitive = true
  default   = env("PACKER_GITHUB_API_TOKEN")
}

variable "image_prefix" {
  default = "forge-runner-base"
}

variable "common_tags" {
  type = map(string)
  default = {
    ApplicationName    = "forge"
    DataClassification = "internal"
    ManagedBy          = "packer"
    Purpose            = "github-runner-base-image"
    SecurityContact    = "platform@example.com"
  }
}

locals {
  release_name  = "${var.image_prefix}-macos${var.macos_major_version}-${var.arch}-${var.version}"
  instance_type = var.arch == "arm64" ? "mac2.metal" : "mac1.metal"
  ami_arch      = var.arch == "arm64" ? "arm64_mac" : "x86_64_mac"

  tags = merge(var.common_tags, {
    Name         = local.release_name
    Architecture = var.arch
    Branch       = var.branch
    JobId        = var.job_id
    OS           = "macos-${var.macos_major_version}"
    Role         = "github-runner"
    Version      = var.version
  })
}

source "amazon-ebs" "macos" {
  ami_name      = local.release_name
  instance_type = local.instance_type

  associate_public_ip_address = false
  ssh_interface               = "private_ip"
  region                      = var.aws_region
  ssh_username                = "ec2-user"

  source_ami_filter {
    filters = {
      name                = "amzn-ec2-macos-${var.macos_major_version}*"
      architecture        = local.ami_arch
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["amazon"]
    most_recent = true
  }

  placement {
    tenancy                 = "host"
    host_resource_group_arn = var.host_resource_group_arn
  }

  license_specifications {
    license_configuration_request {
      license_configuration_arn = var.license_configuration_arn
    }
  }

  ssh_timeout   = "2h"
  ebs_optimized = true

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 100
    volume_type           = "gp3"
    delete_on_termination = true
  }

  temporary_security_group_source_cidrs = [var.builder_allowed_cidr]

  vpc_id            = var.vpc_id
  subnet_id         = var.subnet_id
  availability_zone = var.availability_zone

  tags            = local.tags
  run_tags        = local.tags
  run_volume_tags = local.tags
  snapshot_tags   = merge(local.tags, { Name = "packer-${local.release_name}" })

  aws_polling {
    delay_seconds = 30
    max_attempts  = 240
  }
}

build {
  name = "macos-${var.macos_major_version}-${var.arch}"
  sources = [
    "source.amazon-ebs.macos"
  ]

  provisioner "ansible" {
    ansible_env_vars = [
      "ANSIBLE_ROLES_PATH=ansible/roles",
    ]
    extra_arguments = [
      "-v",
      "-e", "ansible_python_interpreter=/usr/bin/python3",
      "-e", "PACKER_GITHUB_API_TOKEN=${var.gh_pat}",
      "-e", "ARCH=${var.arch}",
    ]
    playbook_file = "ansible/playbooks/build_gh_runner_macos.yml"
    user          = "ec2-user"
    use_proxy     = false
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
