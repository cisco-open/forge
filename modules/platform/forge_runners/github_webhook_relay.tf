resource "random_id" "github_webhook_relay_source_secret" {
  count       = var.github_webhook_relay.enabled ? 1 : 0
  byte_length = 20
}

module "github_webhook_relay_source" {
  count = var.github_webhook_relay.enabled ? 1 : 0

  source = "../../integrations/github_webhook_relay_source"

  name_prefix           = "${var.deployment_config.prefix}-github-webhook-relay"
  source_event_bus_name = "${var.deployment_config.prefix}-webhook-relay-source"
  webhook_secret        = random_id.github_webhook_relay_source_secret[0].hex

  destination_account_id     = var.github_webhook_relay.destination_account_id
  destination_region         = var.github_webhook_relay.destination_region
  destination_event_bus_name = var.github_webhook_relay.destination_event_bus_name

  tags = local.all_security_tags
}

resource "aws_kms_key" "github_webhook_relay" {
  is_enabled = true

  tags = merge(
    local.all_security_tags,
    {
      Name = "${var.deployment_config.prefix}-webhook-relay-kms-key"
    }
  )
  tags_all = local.all_security_tags
}

resource "aws_kms_alias" "github_webhook_relay" {
  name          = "alias/${var.deployment_config.prefix}-webhook-relay"
  target_key_id = aws_kms_key.github_webhook_relay.key_id
}

resource "aws_secretsmanager_secret" "github_webhook_relay" {
  count = var.github_webhook_relay.enabled ? 1 : 0

  name        = "/cicd/common/${var.tenant.name}/${var.deployment_config.secret_suffix}/webhook_relay"
  description = "GitHub webhook relay endpoint + secret"
  kms_key_id  = aws_kms_key.github_webhook_relay.id
  tags        = local.all_security_tags
}

resource "aws_secretsmanager_secret_version" "github_webhook_relay" {
  count = var.github_webhook_relay.enabled ? 1 : 0

  secret_id = aws_secretsmanager_secret.github_webhook_relay[0].id
  secret_string = jsonencode({
    endpoint = module.github_webhook_relay_source[0].webhook_endpoint
    secret   = random_id.github_webhook_relay_source_secret[0].hex
  })
}
data "aws_iam_policy_document" "secret_reader_trust" {
  count = var.github_webhook_relay.enabled && var.github_webhook_relay.destination_reader_role_arn != "" ? 1 : 0

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
  count              = var.github_webhook_relay.enabled ? 1 : 0
  name               = "${var.deployment_config.prefix}-webhook-secret-reader"
  assume_role_policy = data.aws_iam_policy_document.secret_reader_trust[0].json
  tags               = local.all_security_tags
  tags_all           = local.all_security_tags
}

data "aws_iam_policy_document" "secret_reader_permissions" {
  count = var.github_webhook_relay.enabled ? 1 : 0
  statement {
    sid    = "AllowSecretRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [aws_secretsmanager_secret.github_webhook_relay[0].arn]
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
  count = var.github_webhook_relay.enabled ? 1 : 0

  name   = "${var.deployment_config.prefix}-webhook-secret-reader-permissions"
  role   = aws_iam_role.secret_reader[0].id
  policy = data.aws_iam_policy_document.secret_reader_permissions[0].json
}
