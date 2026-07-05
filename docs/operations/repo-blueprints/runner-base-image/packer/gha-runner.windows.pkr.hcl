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

variable "windows_version" {
  default = env("WINDOWS_VERSION")
}

variable "job_id" {
  default = env("JOB_ID")
}

variable "branch" {
  default = env("BRANCH")
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
  release_name = "${var.image_prefix}-windows${var.windows_version}-amd64-${var.version}"
  tags = merge(var.common_tags, {
    Name         = local.release_name
    Architecture = "amd64"
    Branch       = var.branch
    JobId        = var.job_id
    OS           = "windows-${var.windows_version}"
    Role         = "github-runner"
    Version      = var.version
  })
}

source "amazon-ebs" "windows" {
  ami_name = local.release_name

  communicator   = "winrm"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_username = "Administrator"
  winrm_port     = 5986
  winrm_timeout  = "30m"

  force_deregister            = true
  instance_type               = "c6i.4xlarge"
  associate_public_ip_address = false
  region                      = var.aws_region

  source_ami_filter {
    filters = {
      name                = "Windows_Server-${var.windows_version}-English-Full-Base*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["801119661308"]
    most_recent = true
  }

  user_data_file = "packer/windows/bootstrap_winrm.ps1"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 100
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
  name = "windows-${var.windows_version}-amd64"
  sources = [
    "source.amazon-ebs.windows"
  ]

  provisioner "ansible" {
    ansible_env_vars = [
      "ANSIBLE_ROLES_PATH=ansible/roles",
    ]
    playbook_file = "ansible/playbooks/build_gh_runner_windows.yml"
    user          = "Administrator"
    use_proxy     = false

    extra_arguments = [
      "-v",
      "-e", "PACKER_GITHUB_API_TOKEN=${var.gh_pat}",
      "-e", "ansible_password=${build.Password}",
      "-e", "ansible_connection=winrm",
      "-e", "ansible_shell_type=cmd",
      "-e", "ansible_winrm_transport=basic",
      "-e", "ansible_winrm_server_cert_validation=ignore",
    ]
  }

  provisioner "powershell" {
    scripts = [
      "packer/windows/cleanup_ami.ps1",
    ]
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
