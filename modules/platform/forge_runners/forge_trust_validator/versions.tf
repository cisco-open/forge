terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.27"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2"
    }
  }

  # OpenTofu version.
  required_version = ">= 1.9.1"
}
