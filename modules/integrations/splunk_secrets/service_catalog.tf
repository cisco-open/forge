resource "aws_servicecatalogappregistry_application" "this" {
  name = "integrations_splunk_secrets_${var.aws_region}"
  tags = merge(var.default_tags, var.tags)
}

resource "aws_servicecatalogappregistry_application" "replica" {
  for_each = setsubtract(local.all_regions, toset([var.aws_region]))
  provider = aws.by_region[each.value]

  name = "integrations_splunk_secrets_${each.value}"
  tags = merge(var.default_tags, var.tags)
}
