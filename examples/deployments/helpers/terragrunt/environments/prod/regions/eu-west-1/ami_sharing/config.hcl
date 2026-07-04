locals {
  config           = yamldecode(file("config.yml"))
  account_ids      = local.config.account_ids
  ami_name_filters = local.config.ami_name_filters
}
