resource "aws_account_region" "enabled_regions" {
  for_each    = { for region in var.opt_in_regions : region => region }
  region_name = each.key
  enabled     = true
}
