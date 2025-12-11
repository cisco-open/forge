data "aws_iam_policy_document" "splunk_integration" {
  statement {
    effect = "Allow"
    actions = [
      "airflow:GetEnvironment",
      "airflow:ListEnvironments",
      "apigateway:GET",
      "autoscaling:DescribeAutoScalingGroups",
      "cloudformation:ListResources",
      "cloudformation:GetResource",
      "cloudfront:GetDistributionConfig",
      "cloudfront:ListDistributions",
      "cloudfront:ListTagsForResource",
      "directconnect:DescribeConnections",
      "dynamodb:DescribeTable",
      "dynamodb:ListTables",
      "dynamodb:ListTagsOfResource",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeNatGateways",
      "ec2:DescribeRegions",
      "ec2:DescribeReservedInstances",
      "ec2:DescribeReservedInstancesModifications",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:DescribeTasks",
      "ecs:ListClusters",
      "ecs:ListServices",
      "ecs:ListTagsForResource",
      "ecs:ListTaskDefinitions",
      "ecs:ListTasks",
      "eks:DescribeCluster",
      "eks:ListClusters",
      "iam:listAccountAliases",
      "kafka:DescribeCluster",
      "kafka:DescribeClusterV2",
      "kafka:ListClusters",
      "kafka:ListClustersV2",
      "elasticache:DescribeCacheClusters",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticmapreduce:DescribeCluster",
      "elasticmapreduce:ListClusters",
      "es:DescribeElasticsearchDomain",
      "es:ListDomainNames",
      "kinesis:DescribeStream",
      "kinesis:ListShards",
      "kinesis:ListStreams",
      "kinesis:ListTagsForStream",
      "kinesisanalytics:DescribeApplication",
      "kinesisanalytics:ListApplications",
      "kinesisanalytics:ListTagsForResource",
      "lambda:GetAlias",
      "lambda:ListFunctions",
      "lambda:ListTags",
      "logs:DeleteSubscriptionFilter",
      "logs:DescribeLogGroups",
      "logs:DescribeSubscriptionFilters",
      "logs:PutSubscriptionFilter",
      "network-firewall:DescribeFirewall",
      "network-firewall:ListFirewalls",
      "organizations:DescribeOrganization",
      "rds:DescribeDBInstances",
      "rds:DescribeDBClusters",
      "rds:ListTagsForResource",
      "redshift:DescribeClusters",
      "redshift:DescribeLoggingStatus",
      "s3:GetBucketLocation",
      "s3:GetBucketLogging",
      "s3:GetBucketNotification",
      "s3:GetBucketTagging",
      "s3:ListAllMyBuckets",
      "s3:ListBucket",
      "s3:PutBucketNotification",
      "sqs:GetQueueAttributes",
      "sqs:ListQueues",
      "sqs:ListQueueTags",
      "states:ListActivities",
      "states:ListStateMachines",
      "tag:GetResources",
      "workspaces:DescribeWorkspaces"
    ]
    resources = ["*"]
  }

  statement {
    effect  = "Allow"
    actions = ["cassandra:Select"]
    resources = [
      "arn:aws:cassandra:*:*:/keyspace/system/table/local",
      "arn:aws:cassandra:*:*:/keyspace/system/table/peers",
      "arn:aws:cassandra:*:*:/keyspace/system_schema/*",
      "arn:aws:cassandra:*:*:/keyspace/system_schema_mcs/table/tags",
      "arn:aws:cassandra:*:*:/keyspace/system_schema_mcs/table/tables",
      "arn:aws:cassandra:*:*:/keyspace/system_schema_mcs/table/columns"
    ]
  }
}

data "aws_iam_policy_document" "splunk_managed_policy" {
  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricStream",
      "cloudwatch:ListMetricStreams",
      "cloudwatch:PutMetricStream",
      "cloudwatch:DeleteMetricStream",
      "cloudwatch:StartMetricStreams",
      "cloudwatch:StopMetricStreams",
      "ec2:DescribeRegions",
      "organizations:DescribeOrganization",
      "tag:GetResources"
    ]
    resources = ["*"]
  }

  statement {
    effect  = "Allow"
    actions = ["iam:PassRole"]
    # Role to be created by Cloudformation stack
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/splunk-metric-streams*"]
  }
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [signalfx_aws_external_integration.integration.signalfx_aws_account]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [signalfx_aws_external_integration.integration.external_id]
    }
  }

}

resource "aws_iam_role" "splunk_integration" {
  name               = "splunk-o11y-sp"
  description        = "Splunk Observability Cloud integration to read out data and send it to signalfxs aws account"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

resource "aws_iam_role_policy" "splunk_integration" {
  name = "SplunkObservabilityPolicy"
  role = aws_iam_role.splunk_integration.id

  policy = data.aws_iam_policy_document.splunk_integration.json
}

resource "aws_iam_role_policy" "splunk_managed_policy" {
  name = "SplunkManagedMetricStreams"
  role = aws_iam_role.splunk_integration.id

  policy = data.aws_iam_policy_document.splunk_managed_policy.json
}
