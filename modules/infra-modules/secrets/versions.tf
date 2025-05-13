terraform {
  # Provider versions.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
  }

  # OpenTofu version.
  required_version = ">= 1.9.0"
}
