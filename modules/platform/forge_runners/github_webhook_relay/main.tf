resource "random_id" "github_webhook_relay_source_secret" {
  byte_length = 20
}

module "github_webhook_relay_source" {

  source = "../../../integrations/github_webhook_relay_source"

  name_prefix           = "${var.prefix}-github-webhook-relay"
  source_event_bus_name = "${var.prefix}-webhook-relay-source"
  webhook_secret        = random_id.github_webhook_relay_source_secret.hex

  destination_account_id     = var.github_webhook_relay.destination_account_id
  destination_region         = var.github_webhook_relay.destination_region
  destination_event_bus_name = var.github_webhook_relay.destination_event_bus_name

  logging_retention_in_days = var.logging_retention_in_days
  log_level                 = var.log_level

  tags = var.tags
}

resource "aws_kms_key" "github_webhook_relay" {
  is_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.prefix}-webhook-relay-kms-key"
    }
  )
  tags_all = var.tags
}

resource "aws_kms_alias" "github_webhook_relay" {
  name          = "alias/${var.prefix}-webhook-relay"
  target_key_id = aws_kms_key.github_webhook_relay.key_id
}

resource "aws_secretsmanager_secret" "github_webhook_relay" {

  name        = "${var.secret_prefix}/webhook_relay"
  description = "GitHub webhook relay endpoint + secret"
  kms_key_id  = aws_kms_key.github_webhook_relay.id
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "github_webhook_relay" {

  secret_id = aws_secretsmanager_secret.github_webhook_relay.id
  secret_string = jsonencode({
    endpoint = module.github_webhook_relay_source.webhook_endpoint
    secret   = random_id.github_webhook_relay_source_secret.hex
  })
}
data "aws_iam_policy_document" "secret_reader_trust" {

  statement {
    sid     = "AllowExternalRoleAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.github_webhook_relay.destination_reader_role_arn]
    }
  }
}

resource "aws_iam_role" "secret_reader" {
  name               = "${var.prefix}-webhook-secret-reader"
  assume_role_policy = data.aws_iam_policy_document.secret_reader_trust.json
  tags               = var.tags
  tags_all           = var.tags
}

data "aws_iam_policy_document" "secret_reader_permissions" {
  statement {
    sid    = "AllowSecretRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [aws_secretsmanager_secret.github_webhook_relay.arn]
  }

  dynamic "statement" {
    for_each = length(aws_kms_key.github_webhook_relay.arn) > 0 ? [1] : []
    content {
      sid       = "AllowKmsDecrypt"
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = [aws_kms_key.github_webhook_relay.arn]
    }
  }
}

resource "aws_iam_role_policy" "secret_reader_inline" {

  name   = "${var.prefix}-webhook-secret-reader-permissions"
  role   = aws_iam_role.secret_reader.id
  policy = data.aws_iam_policy_document.secret_reader_permissions.json
}
