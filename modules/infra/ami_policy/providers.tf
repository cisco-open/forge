# Re-use AWS settings from root module.
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  # Required, as per security guidelines.
  default_tags {
    tags = var.default_tags
  }
}
