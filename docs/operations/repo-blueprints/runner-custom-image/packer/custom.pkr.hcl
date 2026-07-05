packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1.3"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1.1"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "base_ami_name" {
  type    = string
  default = "forge-runner-base-ubuntu24-*"
}

variable "image_version" {
  type = string
}

source "amazon-ebs" "custom" {
  region        = var.aws_region
  instance_type = "t3.large"
  ssh_username  = "ubuntu"
  ami_name      = "forge-runner-custom-ubuntu24-${var.image_version}"

  source_ami_filter {
    filters = {
      name                = var.base_ami_name
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["self"]
    most_recent = true
  }

  tags = {
    Name      = "forge-runner-custom-ubuntu24"
    ManagedBy = "packer"
    Purpose   = "forge-runner-custom"
  }
}

build {
  sources = ["source.amazon-ebs.custom"]

  provisioner "ansible" {
    playbook_file = "ansible/playbooks/custom.yml"
  }
}
