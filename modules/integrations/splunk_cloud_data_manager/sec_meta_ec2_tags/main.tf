module "splunk_dm_metadata_ec2inst_pattern_tags_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.2"

  role_name = "SplunkDMMetadataEC2InstPatternTags-${var.region}"

  function_name = "SplunkDMMetadataEC2InstPatternTags"
  handler       = "sec_meta_ec2_tags.lambda_handler"
  runtime       = "python3.12"
  timeout       = 900
  architectures = ["x86_64"]

  source_path = [{
    path = "${path.module}/lambda"
  }]

  logging_log_group                 = aws_cloudwatch_log_group.splunk_dm_metadata_ec2inst_pattern_tags_lambda.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = false

  environment_variables = var.environment_variables

  attach_policy_json = true

  policy_json = data.aws_iam_policy_document.splunk_dm_metadata_ec2inst_pattern_tags_lambda.json

  function_tags = var.tags
  role_tags     = var.tags
  tags          = var.tags

  depends_on = [aws_cloudwatch_log_group.splunk_dm_metadata_ec2inst_pattern_tags_lambda]
}

data "aws_iam_policy_document" "splunk_dm_metadata_ec2inst_pattern_tags_lambda" {

  statement {
    actions = [
      "ec2:DescribeInstances"
    ]
    effect    = "Allow"
    resources = ["*"]
    sid       = "EC2InstMetadataReadPermission"
  }
}

resource "aws_cloudwatch_log_group" "splunk_dm_metadata_ec2inst_pattern_tags_lambda" {
  name              = "/aws/lambda/SplunkDMMetadataEC2InstPatternTags"
  retention_in_days = 3
  tags              = var.tags
  tags_all          = var.tags
}

resource "aws_cloudwatch_event_rule" "splunk_dm_metadata_ec2inst_pattern_tags_lambda" {
  name        = "SplunkDMMetadataEC2InstPatternTags"
  description = "Trigger Lambda when EC2 tags are added"

  event_pattern = jsonencode({
    "source"      = ["aws.ec2"],
    "detail-type" = ["AWS API Call via CloudTrail"],
    "detail" = {
      "eventSource" = ["ec2.amazonaws.com"],
      "eventName"   = ["CreateTags"],
      "requestParameters" = {
        "resourcesSet" = {
          "items" = {
            "resourceId" = [
              { "prefix" = "i-" }
            ]
          }
        }
      }
    }
  })

  depends_on = [module.splunk_dm_metadata_ec2inst_pattern_tags_lambda]
}

resource "aws_cloudwatch_event_target" "splunk_dm_metadata_ec2inst_pattern_tags_lambda" {
  rule = aws_cloudwatch_event_rule.splunk_dm_metadata_ec2inst_pattern_tags_lambda.name
  arn  = module.splunk_dm_metadata_ec2inst_pattern_tags_lambda.lambda_function_arn

  depends_on = [module.splunk_dm_metadata_ec2inst_pattern_tags_lambda]
}

resource "aws_lambda_permission" "splunk_dm_metadata_ec2inst_pattern_tags_lambda" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.splunk_dm_metadata_ec2inst_pattern_tags_lambda.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.splunk_dm_metadata_ec2inst_pattern_tags_lambda.arn

  depends_on = [module.splunk_dm_metadata_ec2inst_pattern_tags_lambda]
}
