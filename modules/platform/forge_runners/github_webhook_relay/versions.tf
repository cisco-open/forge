terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.25"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
  }

  # OpenTofu version.
  required_version = ">= 1.10"
}
