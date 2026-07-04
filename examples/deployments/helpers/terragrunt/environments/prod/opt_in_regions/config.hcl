locals {
  config         = yamldecode(file("config.yml"))
  opt_in_regions = local.config.opt_in_regions
}
