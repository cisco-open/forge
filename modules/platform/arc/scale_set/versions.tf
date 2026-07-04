terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.47"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0"
    }
  }

  # OpenTofu version.
  required_version = "~> 1.11"
}
