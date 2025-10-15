locals {
  cur_per_resource_process_lambda_name = "forge-aws-billing-per-resource-process"
}

module "cur_per_resource_process" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.0"

  function_name = local.cur_per_resource_process_lambda_name
  description   = "Processes AWS billing data and sends to Splunk"

  handler       = "handler_per_resource_process.lambda_handler"
  runtime       = "python3.12"
  architectures = ["x86_64"]
  memory_size   = 10240
  timeout       = 900
  publish       = true

  source_path = [{
    path = "${path.module}/lambda",
  }]

  layers = [
    "arn:aws:lambda:${var.aws_region}:770693421928:layer:Klayers-p312-requests:17",
    "arn:aws:lambda:${var.aws_region}:336392948345:layer:AWSSDKPandas-Python312:19"
  ]

  logging_log_group                 = aws_cloudwatch_log_group.cur_per_resource_process.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = true

  environment_variables = {
    SPLUNK_HEC_URL       = var.splunk_aws_billing_config.splunk_hec_url
    SPLUNK_HEC_TOKEN     = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_hec_token_aws_billing"].secret_string
    SPLUNK_INDEX         = var.splunk_aws_billing_config.splunk_index
    SPLUNK_METRICS_TOKEN = data.aws_secretsmanager_secret_version.secrets["splunk_o11y_ingest_token_aws_billing"].secret_string
    SPLUNK_METRICS_URL   = var.splunk_aws_billing_config.splunk_metrics_url
  }

  attach_policy_jsons = true
  policy_jsons = [
    data.aws_iam_policy_document.lambda_policy_document.json,
  ]
  number_of_policy_jsons = 1

  tags = local.all_security_tags

  store_on_s3         = true
  s3_object_tags_only = true
  s3_object_tags      = var.default_tags
  s3_bucket           = aws_s3_bucket.aws_billing_report.id
  s3_prefix           = "lambda/billing_per_resource_process"
}

resource "aws_lambda_permission" "cur_per_resource_process" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = module.cur_per_resource_process.lambda_function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${aws_s3_bucket.aws_billing_report.id}"
}

resource "aws_cloudwatch_log_group" "cur_per_resource_process" {
  name              = "/aws/lambda/${local.cur_per_resource_process_lambda_name}"
  retention_in_days = 3
  tags              = local.all_security_tags
  tags_all          = local.all_security_tags
}
