locals {
  function_name = "ForgeSplunkDMLogGroupReconciler-${var.region}"
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "log_group_reconciler" {
  statement {
    sid       = "DiscoverSplunkDataManagerFunctions"
    effect    = "Allow"
    actions   = ["cloudformation:ListStackResources"]
    resources = ["arn:${data.aws_partition.current.partition}:cloudformation:${var.region}:${data.aws_caller_identity.current.account_id}:stack/SplunkDM*/*"]
  }

  statement {
    sid    = "ManageSplunkDataManagerLogGroups"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:TagResource",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/SplunkDM*"]
  }
}

module "log_group_reconciler" {
  #checkov:skip=CKV_TF_1:Module source uses a Renovate-managed release tag.
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.8.0"

  region        = var.region
  function_name = local.function_name
  role_name     = local.function_name
  description   = "Tags and deletes Splunk Data Manager Lambda log groups."
  handler       = "log_group_reconciler.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60
  memory_size   = 128
  architectures = ["x86_64"]

  reserved_concurrent_executions = 2

  source_path = [{
    path = "${path.module}/lambda"
  }]

  trigger_on_package_timestamp      = false
  cloudwatch_logs_retention_in_days = 3
  logging_log_group                 = "/aws/lambda/${local.function_name}"
  logging_log_format                = "Text"

  environment_variables = {
    EXPECTED_ACCOUNT_ID  = data.aws_caller_identity.current.account_id
    EXPECTED_PARTITION   = data.aws_partition.current.partition
    EXPECTED_REGION      = var.region
    FUNCTION_NAME_PREFIX = "SplunkDM"
  }

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.log_group_reconciler.json

  attach_create_log_group_permission = false

  function_tags        = var.tags
  role_tags            = var.tags
  cloudwatch_logs_tags = var.tags
  tags                 = var.tags
}

resource "aws_cloudwatch_event_rule" "lambda_delete" {
  name        = "${local.function_name}-delete"
  description = "Delete the log group after a Splunk Data Manager Lambda is deleted."
  region      = var.region
  tags        = var.tags

  event_pattern = jsonencode({
    source        = ["aws.lambda"]
    "detail-type" = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["lambda.amazonaws.com"]
      eventName   = ["DeleteFunction20150331"]
      errorCode   = [{ exists = false }]
      requestParameters = {
        functionName = [
          { prefix = "SplunkDM" },
          { prefix = "arn:${data.aws_partition.current.partition}:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:SplunkDM" },
        ]
        qualifier = [{ exists = false }]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda_delete" {
  arn       = module.log_group_reconciler.lambda_function_arn
  region    = var.region
  rule      = aws_cloudwatch_event_rule.lambda_delete.name
  target_id = "SplunkDMLogGroupDelete"

  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 10
  }
}

resource "aws_lambda_permission" "lambda_delete" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.log_group_reconciler.lambda_function_name
  principal     = "events.amazonaws.com"
  region        = var.region
  source_arn    = aws_cloudwatch_event_rule.lambda_delete.arn
}
