resource "aws_dynamodb_table" "dedupe" {
  name             = "${var.name_prefix}-dedupe"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "dedupe_key"
  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"

  attribute {
    name = "dedupe_key"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}
