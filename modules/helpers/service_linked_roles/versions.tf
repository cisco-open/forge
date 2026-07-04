terraform {
  # Provider versions.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.47"
    }
  }

  # OpenTofu version.
  required_version = "~> 1.11"
}
