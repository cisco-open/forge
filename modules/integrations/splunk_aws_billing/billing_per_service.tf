resource "null_resource" "install_dependencies_per_service" {
  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/requirements_per_service.sh /tmp/aws_billing/per_service/${var.aws_profile}"
  }

  triggers = {
    lambda_source_hash        = filesha256("${path.module}/lambda/handler_per_service.py")
    requirements_hash         = filesha256("${path.module}/lambda/requirements.txt")
    requirements_handler_hash = filesha256("${path.module}/scripts/requirements_per_service.sh")
  }
}

resource "aws_s3_object" "cur_per_service" {
  bucket = aws_s3_bucket.aws_billing_report.id
  key    = "lambda/aws_billing_lambda_function_per_service-${null_resource.install_dependencies_per_service.id}.zip"
  source = "/tmp/aws_billing/per_service/${var.aws_profile}/lambda_package/lambda.zip"

  depends_on = [null_resource.install_dependencies_per_service]
}

resource "aws_lambda_function" "cur_per_service" {
  function_name = "forge-aws-billing-per-service"
  s3_bucket     = aws_s3_object.cur_per_service.bucket
  s3_key        = aws_s3_object.cur_per_service.key
  handler       = "handler.lambda_handler"
  architectures = ["x86_64"]
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_exec_role.arn
  timeout       = 900
  memory_size   = 10240

  environment {
    variables = {
      SPLUNK_HEC_URL       = var.splunk_aws_billing_config.splunk_hec_url
      SPLUNK_HEC_TOKEN     = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_hec_token_aws_billing"].secret_string
      SPLUNK_INDEX         = var.splunk_aws_billing_config.splunk_index
      SPLUNK_METRICS_TOKEN = data.aws_secretsmanager_secret_version.secrets["splunk_o11y_metrics_token_aws_billing"].secret_string
      SPLUNK_METRICS_URL   = var.splunk_aws_billing_config.splunk_metrics_url
    }
  }
}

resource "aws_s3_bucket_notification" "cur_notification" {
  bucket = aws_s3_bucket.aws_billing_report.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.cur_per_service.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "cur-per-service/aws-billing-report/data/"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cur_per_service.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${aws_s3_bucket.aws_billing_report.id}"
}

resource "aws_cloudwatch_log_group" "cur_per_service" {
  name              = "/aws/lambda/${aws_lambda_function.cur_per_service.function_name}"
  retention_in_days = 3
  tags              = local.all_security_tags
  tags_all          = local.all_security_tags
}

resource "aws_bcmdataexports_export" "cur_per_service" {
  export {
    name = "aws-billing-report-per-service"
    data_query {
      query_statement = <<EOF
      SELECT
        identity_line_item_id,
        identity_time_interval,
        line_item_product_code,
        line_item_unblended_cost,
        line_item_usage_start_date,
        line_item_net_unblended_cost,
        resource_tags,
        cost_category
      FROM COST_AND_USAGE_REPORT
      EOF
      table_configurations = {
        COST_AND_USAGE_REPORT = {
          TIME_GRANULARITY                      = "DAILY",
          INCLUDE_RESOURCES                     = "FALSE",
          INCLUDE_MANUAL_DISCOUNT_COMPATIBILITY = "FALSE",
          INCLUDE_SPLIT_COST_ALLOCATION_DATA    = "FALSE",
        }
      }
    }
    destination_configurations {
      s3_destination {
        s3_bucket = aws_s3_bucket.aws_billing_report.id
        s3_prefix = "cur-per-service"
        s3_region = var.aws_region
        s3_output_configurations {
          overwrite   = "CREATE_NEW_REPORT"
          format      = "PARQUET"
          compression = "PARQUET"
          output_type = "CUSTOM"
        }
      }
    }

    refresh_cadence {
      frequency = "SYNCHRONOUS"
    }
  }
}
