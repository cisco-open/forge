locals {
  cur_per_resource_lambda_name = "forge-aws-billing-per-resource"
}

module "cur_per_resource" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.0"

  function_name = local.cur_per_resource_lambda_name
  description   = "Processes AWS Billing CUR reports per resource and sends data to Splunk"

  handler       = "handler_per_resource.lambda_handler"
  runtime       = "python3.12"
  architectures = ["x86_64"]
  memory_size   = 10240
  timeout       = 900
  publish       = true

  source_path = [{
    path             = "${path.module}/lambda"
    pip_requirements = "${path.module}/lambda/requirements.txt"
  }]

  logging_log_group                 = aws_cloudwatch_log_group.cur_per_resource.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = false

  environment_variables = {
    SPLUNK_HEC_URL       = var.splunk_aws_billing_config.splunk_hec_url
    SPLUNK_HEC_TOKEN     = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_hec_token_aws_billing"].secret_string
    SPLUNK_INDEX         = var.splunk_aws_billing_config.splunk_index
    SPLUNK_METRICS_TOKEN = data.aws_secretsmanager_secret_version.secrets["splunk_o11y_ingest_token_aws_billing"].secret_string
    SPLUNK_METRICS_URL   = var.splunk_aws_billing_config.splunk_metrics_url
  }

  attach_policy_jsons = true
  policy_jsons = [
    data.aws_iam_policy_document.cur_per_resource.json,
    data.aws_iam_policy_document.lambda_policy_document.json,
  ]
  number_of_policy_jsons = 2

  tags = local.all_security_tags

  store_on_s3         = true
  s3_object_tags_only = true
  s3_object_tags      = var.default_tags
  s3_bucket           = aws_s3_bucket.aws_billing_report.id
  s3_prefix           = "lambda/aws_billing_lambda_function_per_resource_process"
}

resource "aws_lambda_permission" "cur_per_resource" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = local.cur_per_resource_lambda_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${aws_s3_bucket.aws_billing_report.id}"
}

resource "aws_cloudwatch_log_group" "cur_per_resource" {
  name              = "/aws/lambda/${local.cur_per_resource_lambda_name}"
  retention_in_days = 3
  tags              = local.all_security_tags
  tags_all          = local.all_security_tags
}

data "aws_iam_policy_document" "cur_per_resource" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect = "Allow"

    resources = [
      "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.cur_per_resource.name}*:*"
    ]
  }
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
