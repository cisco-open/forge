resource "null_resource" "install_dependencies_per_resource_process" {
  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/requirements.sh /tmp/aws_billing/per_resource_process/${var.aws_profile} handler_per_resource_process"
  }

  triggers = {
    lambda_source_hash        = filesha256("${path.module}/lambda/handler_per_resource_process.py")
    common_source_hash        = filesha256("${path.module}/lambda/common.py")
    requirements_hash         = filesha256("${path.module}/lambda/requirements.txt")
    requirements_handler_hash = filesha256("${path.module}/scripts/requirements.sh")
  }
}

resource "aws_s3_object" "cur_per_resource_process" {
  bucket = aws_s3_bucket.aws_billing_report.id
  key    = "lambda/aws_billing_lambda_function_per_resource_process-${null_resource.install_dependencies_per_resource_process.id}.zip"
  source = "/tmp/aws_billing/per_resource_process/${var.aws_profile}/lambda_package/lambda.zip"

  depends_on = [null_resource.install_dependencies_per_resource_process]
}

resource "aws_lambda_function" "cur_per_resource_process" {
  function_name = "forge-aws-billing-per-resource-process"
  s3_bucket     = aws_s3_object.cur_per_resource_process.bucket
  s3_key        = aws_s3_object.cur_per_resource_process.key
  handler       = "handler_per_resource_process.lambda_handler"
  architectures = ["x86_64"]
  runtime       = "python3.12"
  role          = aws_iam_role.lambda_exec_role.arn
  timeout       = 900
  memory_size   = 10240

  environment {
    variables = {
      SPLUNK_HEC_URL       = var.splunk_aws_billing_config.splunk_hec_url
      SPLUNK_HEC_TOKEN     = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_hec_token_aws_billing"].secret_string
      SPLUNK_INDEX         = var.splunk_aws_billing_config.splunk_index
      SPLUNK_METRICS_TOKEN = data.aws_secretsmanager_secret_version.secrets["splunk_o11y_ingest_token_aws_billing"].secret_string
      SPLUNK_METRICS_URL   = var.splunk_aws_billing_config.splunk_metrics_url
    }
  }
}

resource "aws_lambda_permission" "cur_per_resource_process" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cur_per_resource_process.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${aws_s3_bucket.aws_billing_report.id}"
}

resource "aws_cloudwatch_log_group" "cur_per_resource_process" {
  name              = "/aws/lambda/${aws_lambda_function.cur_per_resource_process.function_name}"
  retention_in_days = 3
  tags              = local.all_security_tags
  tags_all          = local.all_security_tags
}
