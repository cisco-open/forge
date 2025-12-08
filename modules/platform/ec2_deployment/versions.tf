terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.25"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.7.0"
    }
  }

  # OpenTofu version.
  required_version = ">= 1.10"
}
