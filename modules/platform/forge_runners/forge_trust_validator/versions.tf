terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.25"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2"
    }
  }

  # OpenTofu version.
  required_version = ">= 1.10"
}
