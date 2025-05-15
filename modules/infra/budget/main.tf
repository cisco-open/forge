# Define sub-modules and other significant settings/resources/etc. here.
# Overall monthly budget.
resource "aws_budgets_budget" "budget_monthly_overall" {
  name              = "(${var.aws_account_id}) => Overall Monthly Budget"
  budget_type       = "COST"
  limit_amount      = var.aws_budget.per_account
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2020-01-01_00:00"

  # Notify if we predict we're going to exceed our budget.
  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 100
    threshold_type      = "PERCENTAGE"
    notification_type   = "FORECASTED"
    subscriber_sns_topic_arns = [
      data.aws_sns_topic.account_billing_alarm_topic.arn
    ]
  }

  depends_on = [
    data.aws_sns_topic.account_billing_alarm_topic
  ]
}

# Granular per-service budget.
resource "aws_budgets_budget" "budget_monthly_per_service" {
  for_each = var.aws_budget.services

  name              = "(${var.aws_account_id}) => Service ${each.key} Monthly Budget"
  budget_type       = "COST"
  limit_amount      = each.value.budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2020-01-01_00:00"

  cost_filter {
    # Filter by service type (case-sensitive).
    name   = "Service"
    values = [local.aws_services[each.key]]
  }

  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 100
    threshold_type      = "PERCENTAGE"
    notification_type   = "FORECASTED"
    subscriber_sns_topic_arns = [
      data.aws_sns_topic.account_billing_alarm_topic.arn
    ]
  }

  depends_on = [
    data.aws_sns_topic.account_billing_alarm_topic
  ]
}

# SNS topic and associated policy-related functionality. This allows the budget
# resource to make use of this topic (i.e. publish alerts).
data "aws_sns_topic" "account_billing_alarm_topic" {
  name = "account-billing-alarm-topic"
}

# Various services supported by AWS.
locals {
  aws_services = {
    Athena         = "Amazon Athena"
    EC2            = "Amazon Elastic Compute Cloud - Compute"
    ECR            = "Amazon EC2 Container Registry (ECR)"
    ECS            = "Amazon EC2 Container Service"
    Kubernetes     = "Amazon Elastic Container Service for Kubernetes"
    EBS            = "Amazon Elastic Block Store"
    CloudFront     = "Amazon CloudFront"
    CloudTrail     = "AWS CloudTrail"
    CloudWatch     = "AmazonCloudWatch"
    Cognito        = "Amazon Cognito"
    Config         = "AWS Config"
    DynamoDB       = "Amazon DynamoDB"
    DMS            = "AWS Database Migration Service"
    ElastiCache    = "Amazon ElastiCache"
    Elasticsearch  = "Amazon Elasticsearch Service"
    ELB            = "Amazon Elastic Load Balancing"
    Gateway        = "Amazon API Gateway"
    Glue           = "AWS Glue"
    Kafka          = "Managed Streaming for Apache Kafka"
    KMS            = "AWS Key Management Service"
    Kinesis        = "Amazon Kinesis"
    Lambda         = "AWS Lambda"
    Lex            = "Amazon Lex"
    Matillion      = "Matillion ETL for Amazon Redshift"
    Pinpoint       = "AWS Pinpoint"
    Polly          = "Amazon Polly"
    Rekognition    = "Amazon Rekognition"
    RDS            = "Amazon Relational Database Service"
    Redshift       = "Amazon Redshift"
    S3             = "Amazon Simple Storage Service"
    SFTP           = "AWS Transfer for SFTP"
    Route53        = "Amazon Route 53"
    SageMaker      = "Amazon SageMaker"
    SecretsManager = "AWS Secrets Manager"
    SES            = "Amazon Simple Email Service"
    SNS            = "Amazon Simple Notification Service"
    SQS            = "Amazon Simple Queue Service"
    Tax            = "Tax"
    VPC            = "Amazon Virtual Private Cloud"
    WAF            = "AWS WAF"
    XRay           = "AWS X-Ray"
  }
}
