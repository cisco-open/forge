locals {
  all_security_tags = merge(var.default_tags, var.tags)
}
