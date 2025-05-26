resource "aws_dynamodb_table" "orchestrator" {
  name         = "forge-orchestrator"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "config_id"

  attribute {
    name = "config_id"
    type = "S"
  }

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}
