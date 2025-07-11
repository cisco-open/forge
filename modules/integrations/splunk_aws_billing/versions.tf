terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.27"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  # OpenTofu version.
  required_version = ">= 1.9.1"
}
