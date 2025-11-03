provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  # Required, as per security guidelines.
  default_tags {
    tags = merge(var.default_tags, )
  }
}
