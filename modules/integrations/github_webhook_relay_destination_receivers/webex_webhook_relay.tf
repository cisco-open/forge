locals {
  webex_target = var.enable_webex_webhook_relay ? [{
    event_pattern       = <<EOF
{
  "detail": {
    "action": ["completed"]
  }
}
EOF
    lambda_function_arn = module.webex_webhook_relay[0].lambda_function_arn
  }] : []
}

# Destination module wiring: create bus, rules, and permissions referencing our lambdas
module "webex_webhook_relay" {
  count  = var.enable_webex_webhook_relay ? 1 : 0
  source = "./webex_webhook_relay"

  providers = {
    aws = aws
  }

  log_retention_days = var.log_retention_days
  aws_region         = var.aws_region
  tags               = var.tags
  default_tags       = var.default_tags
}
