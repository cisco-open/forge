data "aws_iam_policy_document" "splunk_dm_policy" {
  statement {
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:PassRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:GetPolicy",
      "iam:GetPolicyVersion"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/SplunkDM*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/*"
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["guardduty:GetMasterAccount"]
    resources = ["arn:aws:guardduty:*:${data.aws_caller_identity.current.account_id}:detector/*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "securityhub:GetEnabledStandards",
      "securityhub:GetMasterAccount",
      "securityhub:ListMembers",
      "securityhub:ListInvitations"
    ]
    resources = ["arn:aws:securityhub:*:${data.aws_caller_identity.current.account_id}:hub/default"]
  }

  statement {
    effect = "Allow"
    actions = [
      "cloudformation:DescribeStacks",
      "cloudformation:GetTemplate"
    ]
    resources = ["arn:aws:cloudformation:*:${data.aws_caller_identity.current.account_id}:stack/SplunkDM*/*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricStatistics",
      "cloudtrail:DescribeTrails",
      "guardduty:ListDetectors",
      "guardduty:ListMembers",
      "guardduty:ListInvitations",
      "guardduty:GetFindingsStatistics",
      "access-analyzer:ListAnalyzers",
      "sqs:GetQueueUrl",
      "ec2:DescribeFlowLogs"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "logs:DescribeSubscriptionFilters"
    ]
    resources = ["arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["firehose:DescribeDeliveryStream"]
    resources = ["arn:aws:firehose:*:${data.aws_caller_identity.current.account_id}:deliverystream/SplunkDM*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["events:DescribeRule"]
    resources = ["arn:aws:events:*:${data.aws_caller_identity.current.account_id}:rule/SplunkDM*"]
  }

  statement {
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [
      "arn:aws:s3:::splunkdmfailed*",
      "arn:aws:s3:::sdm-dataingest-cft*"
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["lambda:GetFunction"]
    resources = ["arn:aws:lambda:*:${data.aws_caller_identity.current.account_id}:function:SplunkDM*"]
  }
}

resource "aws_iam_role" "splunk_dm_read_only" {
  name = "SplunkDMReadOnly"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          "AWS" : [lookup(data.external.config.result, "instanceIamRole", "")]
        },
        Effect = "Allow",
        Sid    = "",
        Condition = {
          StringEquals = {
            "sts:ExternalId" = lookup(data.external.config.result, "iamExternalId", "")
          }
        }
      }
    ]
  })

  tags = local.all_security_tags

  depends_on = [data.external.config]
}

resource "aws_iam_role_policy" "splunk_dm_policy_attachment" {
  name   = "SplunkDMReadOnlyPolicy"
  role   = aws_iam_role.splunk_dm_read_only.id
  policy = data.aws_iam_policy_document.splunk_dm_policy.json
}
