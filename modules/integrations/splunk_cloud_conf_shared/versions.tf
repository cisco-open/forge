terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.25"
    }
    splunk = {
      source  = "splunk/splunk"
      version = ">= 1.4.30"
    }
  }

  # OpenTofu version.
  required_version = ">= 1.10"
}
