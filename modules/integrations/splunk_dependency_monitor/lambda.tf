resource "aws_cloudwatch_log_group" "dependency_monitor" {
  #checkov:skip=CKV_AWS_158:CloudWatch KMS encryption is deferred until the existing Forge log-delivery path supports customer-managed keys.
  #checkov:skip=CKV_AWS_338:Retention is operator-configurable because the logs are exported to Splunk Cloud.
  name              = "/aws/lambda/${local.dependency_monitor_function_name}"
  retention_in_days = var.logging_retention_in_days
  tags              = local.all_security_tags
  tags_all          = local.all_security_tags
}

module "dependency_monitor" {
  #checkov:skip=CKV_TF_1:Module source uses a Renovate-managed release tag.
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.8.0"

  function_name = local.dependency_monitor_function_name
  description   = "Probes tenant GitHub App authentication, organization runner API health, rate limits, and regional SSM access."
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = 300
  architectures = ["x86_64"]

  source_path = [{
    path = "${path.module}/lambda"
  }]

  layers = [
    "arn:aws:lambda:${data.aws_region.current.region}:770693421928:layer:Klayers-p312-cryptography:17",
    "arn:aws:lambda:${data.aws_region.current.region}:770693421928:layer:Klayers-p312-requests:17",
    "arn:aws:lambda:${data.aws_region.current.region}:770693421928:layer:Klayers-p312-PyJWT:1",
  ]

  logging_log_group                 = aws_cloudwatch_log_group.dependency_monitor.name
  use_existing_cloudwatch_log_group = true
  trigger_on_package_timestamp      = false

  environment_variables = {
    GITHUB_API_VERSION          = var.github_api_version
    GITHUB_TIMEOUT_SECONDS      = tostring(var.github_timeout_seconds)
    LOG_LEVEL                   = var.log_level
    SPLUNK_HEC_TOKEN            = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_hec_token_dependency_monitor"].secret_string
    SPLUNK_HEC_URL              = var.splunk_dependency_monitor_config.splunk_hec_url
    SPLUNK_HTTP_TIMEOUT_SECONDS = tostring(var.splunk_http_timeout_seconds)
    SPLUNK_INDEX                = var.splunk_dependency_monitor_config.splunk_index
    SPLUNK_METRICS_TOKEN        = data.aws_secretsmanager_secret_version.secrets["splunk_o11y_ingest_token_dependency_monitor"].secret_string
    SPLUNK_METRICS_URL          = var.splunk_dependency_monitor_config.splunk_metrics_url
  }

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.dependency_monitor.json

  function_tags = local.all_security_tags
  role_tags     = local.all_security_tags
  tags          = local.all_security_tags

  depends_on = [
    aws_cloudwatch_log_group.dependency_monitor,
  ]
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "dependency_monitor" {
  statement {
    sid       = "DiscoverRegionalForgeTenants"
    effect    = "Allow"
    actions   = ["ssm:DescribeParameters"]
    resources = ["*"]
  }

  statement {
    sid    = "ReadTenantGitHubAppParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/forge/*/github_app_key",
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/forge/*/github_app_client_id",
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/forge/*/github_app_id",
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/forge/*/github_app_installation_id",
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/forge/*/github_ghes_url",
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/forge/*/github_ghes_org",
    ]
  }

  statement {
    sid       = "ReadTenantTags"
    effect    = "Allow"
    actions   = ["ssm:ListTagsForResource"]
    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/forge/*/github_ghes_org"]
  }

  statement {
    sid       = "DecryptTenantGitHubAppParameters"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["ssm.${var.aws_region}.amazonaws.com"]
    }
  }

}

resource "aws_cloudwatch_event_rule" "dependency_monitor" {
  name                = local.dependency_monitor_function_name
  description         = "Runs regional Forge tenant dependency probes."
  schedule_expression = var.schedule_expression
  tags                = local.all_security_tags
}

resource "aws_cloudwatch_event_target" "dependency_monitor" {
  rule      = aws_cloudwatch_event_rule.dependency_monitor.name
  target_id = "splunk-dependency-monitor"
  arn       = module.dependency_monitor.lambda_function_arn
}

resource "aws_lambda_permission" "eventbridge_invoke" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.dependency_monitor.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.dependency_monitor.arn
}
