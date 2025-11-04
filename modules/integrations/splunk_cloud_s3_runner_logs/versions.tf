terraform {
  # Provider versions.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.90"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3"
    }
  }

  # OpenTofu version.
  required_version = ">= 1.9.1"
}
