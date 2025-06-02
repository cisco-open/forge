packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "1.3.6"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "1.1.3"
    }
  }
}

variable "vpc_id" {
  description = "VPC ID to launch the builder instance in."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to launch the builder instance in."
  type        = string
}

variable "version" {
  description = "Version tag for the build artifact."
  type        = string
  default     = "v0.0.1"
}

variable "job_id" {
  description = "CI/CD job identifier for traceability."
  type        = string
  default     = "manual"
}

variable "branch" {
  description = "Git branch used for the build."
  type        = string
  default     = "main"
}

variable "ssh_username" {
  description = "SSH user for provisioning."
  type        = string
  default     = "ubuntu"
}

variable "allowed_ssh_cidrs" {
  description = "Comma-separated list of CIDR blocks allowed SSH access to the builder instance during the build."
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy the builder"
  type        = string
  default     = "eu-west-1"
}

variable "associate_public_ip" {
  description = "Whether to associate a public IP with the instance"
  type        = bool
  default     = false
}

variable "ssh_interface_type" {
  description = "SSH interface to connect to the instance"
  type        = string
  default     = "private_ip"
}

locals {
  release_name = "gh-runner-base-${var.version}"
}

source "amazon-ebs" "ubuntu" {
  ami_name = local.release_name

  region                      = var.aws_region
  associate_public_ip_address = var.associate_public_ip
  ssh_interface               = var.ssh_interface_type

  spot_price = "auto"
  spot_instance_types = [
    "c6i.8xlarge",
    "c5.9xlarge",
    "c5.12xlarge",
    "c6i.12xlarge",
    "c6i.16xlarge"
  ]

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }

  ssh_username = var.ssh_username

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  temporary_security_group_source_cidrs = split(",", var.allowed_ssh_cidrs)


  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id

  tags = {
    Name    = "packer-${local.release_name}"
    Version = var.version
    Branch  = var.branch
    JobID   = var.job_id
    Role    = "github-runner"
  }

  run_tags = {
    Name    = "packer-${local.release_name}"
    Version = var.version
    Branch  = var.branch
    JobID   = var.job_id
    Role    = "packer-builder"
  }

  aws_polling {
    delay_seconds = 10
    max_attempts  = 180
  }
}

build {
  name    = "build-gh-runner"
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell-local" {
    command = "ansible-galaxy install -r ../ansible/requirements.yml --force"
  }

  provisioner "ansible" {
    playbook_file = "../ansible/build_gh_base_image.yaml"
    user          = var.ssh_username
    use_proxy     = false
    extra_arguments = [
      "-v",
      "-e", "ansible_python_interpreter=/usr/bin/python3"
    ]
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
