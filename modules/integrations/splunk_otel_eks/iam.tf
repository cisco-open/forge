data "aws_iam_openid_connect_provider" "cluster" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

locals {
  oidc_provider_arn = data.aws_iam_openid_connect_provider.cluster.arn
}

data "aws_iam_policy_document" "splunk_otel_assume_role" {

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }

  statement {
    effect = "Allow"

    principals {
      type = "Federated"
      identifiers = [
        local.oidc_provider_arn
      ]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${regex("^arn:aws:iam::\\d+:oidc-provider/(.+)$", local.oidc_provider_arn)[0]}:sub"
      values = [
        "system:serviceaccount:splunk-otel-collector:splunk-otel-collector",
      ]
    }
  }
}

resource "aws_iam_role" "splunk_otel_ec2_describe" {
  name               = "splunk-otel-${var.cluster_name}-ec2-describe-role"
  assume_role_policy = data.aws_iam_policy_document.splunk_otel_assume_role.json

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

data "aws_iam_policy_document" "ec2_describe_instances" {
  statement {
    sid       = "AllowDescribeInstances"
    effect    = "Allow"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ec2_describe_instances" {
  name   = "splunk-otel-${var.cluster_name}-ec2-describe-policy"
  policy = data.aws_iam_policy_document.ec2_describe_instances.json

  tags = local.all_security_tags
}

resource "aws_iam_role_policy_attachment" "splunk_otel_ec2_describe" {
  role       = aws_iam_role.splunk_otel_ec2_describe.name
  policy_arn = aws_iam_policy.ec2_describe_instances.arn
}


resource "aws_eks_pod_identity_association" "eks_pod_identity" {
  cluster_name    = var.cluster_name
  namespace       = "splunk-otel-collector"
  service_account = "splunk-otel-collector"
  role_arn        = aws_iam_role.splunk_otel_ec2_describe.arn

  tags = local.all_security_tags
}
