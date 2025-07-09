resource "null_resource" "install_dependencies_per_resource" {
  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/requirements.sh /tmp/aws_billing/per_resource/${var.aws_profile} handler_per_resource"
  }

  triggers = {
    lambda_source_hash        = filesha256("${path.module}/lambda/handler_per_resource.py")
    requirements_hash         = filesha256("${path.module}/lambda/requirements.txt")
    requirements_handler_hash = filesha256("${path.module}/scripts/requirements.sh")
  }
}

resource "aws_s3_object" "cur_per_resource" {
  bucket = aws_s3_bucket.aws_billing_report.id
  key    = "lambda/aws_billing_lambda_function_per_resource-${null_resource.install_dependencies_per_resource.id}.zip"
  source = "/tmp/aws_billing/per_resource/${var.aws_profile}/lambda_package/lambda.zip"

  depends_on = [null_resource.install_dependencies_per_resource]
}

resource "aws_lambda_function" "cur_per_resource" {
  function_name = "forge-aws-billing-per-resource"
  s3_bucket     = aws_s3_object.cur_per_resource.bucket
  s3_key        = aws_s3_object.cur_per_resource.key
  handler       = "handler_per_resource.lambda_handler"
  architectures = ["x86_64"]
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_exec_role.arn
  timeout       = 900
  memory_size   = 10240
}

resource "aws_lambda_permission" "cur_per_resource" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cur_per_resource.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${aws_s3_bucket.aws_billing_report.id}"
}

resource "aws_cloudwatch_log_group" "cur_per_resource" {
  name              = "/aws/lambda/${aws_lambda_function.cur_per_resource.function_name}"
  retention_in_days = 3
  tags              = local.all_security_tags
  tags_all          = local.all_security_tags
}

resource "aws_bcmdataexports_export" "cur_per_resource" {
  export {
    name = "aws-billing-report-per-resource"
    data_query {
      query_statement = <<EOF
      SELECT
        line_item_resource_id,
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
          INCLUDE_RESOURCES                     = "TRUE",
          INCLUDE_MANUAL_DISCOUNT_COMPATIBILITY = "FALSE",
          INCLUDE_SPLIT_COST_ALLOCATION_DATA    = "TRUE",
        }
      }
    }
    destination_configurations {
      s3_destination {
        s3_bucket = aws_s3_bucket.aws_billing_report.id
        s3_prefix = "cur-per-resource"
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
