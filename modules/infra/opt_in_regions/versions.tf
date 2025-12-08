terraform {
  # Provider versions.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.25"
    }
  }

  # OpenTofu version.
  required_version = ">= 1.10"
}
