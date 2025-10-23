locals {
  cicd_secrets_prefix = "/cicd/common"

  secrets = [
    {
      name          = "${local.cicd_secrets_prefix}/webex_webhook_relay_bot_token"
      description   = "Webex Webhook Relay Bot Token"
      recovery_days = 7
    },
  ]
}

data "aws_secretsmanager_random_password" "secret_seeds" {
  for_each = {
    for key, val in local.secrets : val.name => val
  }

  password_length = 16
}

resource "aws_kms_key" "webex" {
  description         = "Customer managed CMK for Webex Secrets"
  enable_key_rotation = true
  tags                = local.all_security_tags
  tags_all            = local.all_security_tags
}

resource "aws_kms_alias" "webex_alias" {
  name          = "alias/webex-cmk"
  target_key_id = aws_kms_key.webex.id
}

resource "aws_secretsmanager_secret" "cicd_secrets" {
  for_each = {
    for key, val in local.secrets : val.name => val
  }

  name                    = each.value.name
  description             = each.value.description
  kms_key_id              = aws_kms_key.webex.arn
  recovery_window_in_days = each.value.recovery_days
  tags                    = local.all_security_tags
  tags_all                = local.all_security_tags
}

resource "time_sleep" "wait_60_seconds" {
  depends_on = [
    aws_secretsmanager_secret.cicd_secrets,
  ]
  create_duration = "60s"
}

resource "aws_secretsmanager_secret_version" "cicd_secrets" {
  depends_on = [time_sleep.wait_60_seconds]
  for_each = {
    for key, val in local.secrets : val.name => val
  }

  secret_id     = aws_secretsmanager_secret.cicd_secrets[each.key].id
  secret_string = data.aws_secretsmanager_random_password.secret_seeds[each.key].random_password

  lifecycle {
    ignore_changes = [secret_string, ]
  }
}
