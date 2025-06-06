locals {
  global = yamldecode(file("_global.yaml"))

  team_name          = local.global.team_name
  product_name       = local.global.product_name
  project_name       = local.global.project_name
  aws_account_prefix = local.global.aws_account_prefix
  git_org            = local.global.git_org
  group_email        = local.global.group_email
}
