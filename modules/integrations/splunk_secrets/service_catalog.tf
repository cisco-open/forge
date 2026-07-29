resource "aws_servicecatalogappregistry_application" "this" {
  for_each = local.all_regions
  provider = aws.by_region[each.value]

  name = "integrations_splunk_secrets_${each.value}"
  tags = merge(var.default_tags, var.tags)
}
