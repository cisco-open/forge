# Re-use AWS settings from root module.
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  # Required, as per security guidelines.
  default_tags {
    tags = var.default_tags
  }
}


provider "aws" {
  alias = "by_region"
  # supported by opentofu >= 1.9.0
  for_each = toset(local.all_regions)
  profile  = var.aws_profile
  region   = each.key

  # Required, as per security guidelines.
  default_tags {
    tags = var.default_tags
  }
}
