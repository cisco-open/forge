terraform {
  # Provider versions.
  required_providers {
    signalfx = {
      source  = "splunk-terraform/signalfx"
      version = "< 10.0.0"
    }
  }

  # OpenTofu version.
  required_version = ">= 1.9.1"
}
