terraform {
  # Provider versions.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.90"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.36.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.3"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.19.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.13.1"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3"
    }
  }

  # OpenTofu version.
  required_version = ">= 1.9.1"
}
