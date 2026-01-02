data "aws_iam_policy_document" "eks_policy" {
  statement {
    sid    = "EKSDiscovery1"
    effect = "Allow"
    actions = [
      "eks:ListClusters",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EKSDiscovery2"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
    ]
    resources = [data.aws_eks_cluster.cluster.arn]
  }

  statement {
    sid    = "EKSManageAccess"
    effect = "Allow"
    actions = [
      "eks:AssociateAccessPolicy",
      "eks:CreateAccessEntry",
      "eks:DeleteAccessEntry",
      "eks:DescribeAccessEntry",
      "eks:TagResource",
      "eks:UpdateAccessEntry"
    ]
    resources = [data.aws_eks_cluster.cluster.arn]
  }
}

data "aws_iam_policy_document" "trust_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [var.teleport_config.teleport_iam_role_to_assume]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role" "teleport_role" {
  name               = "${var.teleport_config.cluster_name}-teleport"
  assume_role_policy = data.aws_iam_policy_document.trust_policy.json

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

resource "aws_iam_policy" "eks_policy" {
  name        = "${var.teleport_config.cluster_name}-eks-policy"
  description = "Role policy for EKS cluster access"
  policy      = data.aws_iam_policy_document.eks_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_eks_policy" {
  role       = aws_iam_role.teleport_role.name
  policy_arn = aws_iam_policy.eks_policy.arn
}
