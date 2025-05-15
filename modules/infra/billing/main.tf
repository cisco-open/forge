# SNS topic and associated policy-related functionality. This allows the budget
# resource to make use of this topic (i.e. publish alerts).
resource "aws_sns_topic" "account_billing_alarm_topic" {
  name = "account-billing-alarm-topic"
}

# Ensure topic subscribers are emailed on notifications.
resource "aws_sns_topic_subscription" "email-target" {
  topic_arn = aws_sns_topic.account_billing_alarm_topic.arn
  protocol  = "email"
  endpoint  = var.group_email
}

# Map the policy to the topic.
resource "aws_sns_topic_policy" "account_billing_alarm_policy" {
  arn    = aws_sns_topic.account_billing_alarm_topic.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

# Security policy for the topic.
data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    sid    = "AWSBudgetsSNSPublishingPermissions"
    effect = "Allow"

    actions = [
      "SNS:Receive",
      "SNS:Publish"
    ]

    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }

    resources = [
      aws_sns_topic.account_billing_alarm_topic.arn
    ]
  }
}
