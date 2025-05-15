terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.90"
    }
    splunk = {
      source  = "splunk/splunk"
      version = ">= 1.4.30"
    }
  }

  # OpenTofu version.
  required_version = ">= 1.9.1"
}
