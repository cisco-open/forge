terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.25"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.13"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2"
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
