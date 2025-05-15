terraform {
  # Provider versions.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.90"
    }
  }

  # OpenTofu version.
  required_version = ">= 1.9.1"
}
