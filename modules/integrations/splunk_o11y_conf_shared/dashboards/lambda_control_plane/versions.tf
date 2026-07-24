terraform {
  required_providers {
    signalfx = {
      source  = "splunk-terraform/signalfx"
      version = "< 10.0.0"
    }
  }

  required_version = "~> 1.11"
}
