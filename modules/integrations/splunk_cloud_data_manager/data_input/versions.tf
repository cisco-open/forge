terraform {
  # Provider versions.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.25"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.13"
    }
  }

  # OpenTofu version.
  required_version = ">= 1.10"
}
