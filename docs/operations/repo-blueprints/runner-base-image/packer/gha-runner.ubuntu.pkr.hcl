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

variable "ubuntu_version" {
  default = env("UBUNTU_VERSION")
}

variable "gh_pat" {
  sensitive = true
  default   = env("PACKER_GITHUB_API_TOKEN")
}

variable "image_prefix" {
  default = "forge-runner-base"
}

variable "ami_regions" {
  type    = list(string)
  default = ["eu-west-1"]
}

variable "ami_users" {
  type    = list(string)
  default = []
}

variable "ami_org_arns" {
  type    = list(string)
  default = []
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
  ubuntu_arch        = var.arch == "arm64" ? "arm64" : "amd64"
  ubuntu_series      = var.ubuntu_version == "22.04" ? "jammy" : "noble"
  ubuntu_storage     = var.ubuntu_version == "24.04" ? "hvm-ssd-gp3" : "hvm-ssd"
  ubuntu_source_name = "ubuntu/images/${local.ubuntu_storage}/ubuntu-${local.ubuntu_series}-${var.ubuntu_version}-${local.ubuntu_arch}-server-*"
  release_name       = "${var.image_prefix}-ubuntu${replace(var.ubuntu_version, ".", "")}-${var.arch}-${var.version}"

  amd64_instance_types = [
    "c6i.4xlarge",
    "c6i.8xlarge",
    "m6i.4xlarge",
  ]

  arm64_instance_types = [
    "c7g.4xlarge",
    "c7g.8xlarge",
    "m7g.4xlarge",
  ]

  instance_types = var.arch == "arm64" ? local.arm64_instance_types : local.amd64_instance_types

  tags = merge(var.common_tags, {
    Name         = local.release_name
    Architecture = var.arch
    Branch       = var.branch
    JobId        = var.job_id
    OS           = "ubuntu-${var.ubuntu_version}"
    Role         = "github-runner"
    Version      = var.version
  })
}

source "amazon-ebs" "ubuntu" {
  ami_name = local.release_name

  spot_price                  = "auto"
  spot_instance_types         = local.instance_types
  associate_public_ip_address = false
  ssh_interface               = "private_ip"
  region                      = var.aws_region
  ssh_username                = "ubuntu"

  source_ami_filter {
    filters = {
      name                = local.ubuntu_source_name
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"]
    most_recent = true
  }

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 64
    volume_type           = "gp3"
    delete_on_termination = true
  }

  temporary_security_group_source_cidrs = [var.builder_allowed_cidr]

  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id

  ami_regions  = var.ami_regions
  ami_users    = var.ami_users
  ami_org_arns = var.ami_org_arns

  tags            = local.tags
  run_tags        = local.tags
  run_volume_tags = local.tags
  snapshot_tags   = merge(local.tags, { Name = "packer-${local.release_name}" })

  aws_polling {
    delay_seconds = 15
    max_attempts  = 240
  }
}

build {
  name = "ubuntu-${var.ubuntu_version}-${var.arch}"
  sources = [
    "source.amazon-ebs.ubuntu"
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
    playbook_file = "ansible/playbooks/build_gh_runner.yml"
    user          = "ubuntu"
    use_proxy     = false
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
