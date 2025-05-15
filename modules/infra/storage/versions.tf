# Needed to interact with in-house/on-prem SLVM resources.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
  # OpenTofu version.
  required_version = ">= 1.9.0"
}
