terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.47"
    }
  }

  required_version = "~> 1.11"
}
