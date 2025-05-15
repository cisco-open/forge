data "aws_iam_policy_document" "eks_policy" {
  statement {
    sid    = "EKSListPolicy"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
    ]
    resources = ["*"]
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
  name               = "${var.release_name}-teleport"
  assume_role_policy = data.aws_iam_policy_document.trust_policy.json

  tags     = var.tags
  tags_all = var.tags
}

resource "aws_iam_policy" "eks_policy" {
  name        = "${var.release_name}-eks-policy"
  description = "Role policy for EKS cluster access"
  policy      = data.aws_iam_policy_document.eks_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_eks_policy" {
  role       = aws_iam_role.teleport_role.name
  policy_arn = aws_iam_policy.eks_policy.arn
}

resource "kubernetes_cluster_role" "impersonate" {
  metadata {
    name = "teleport-${var.namespace}-impersonate"
  }

  rule {
    api_groups = [""]
    resources  = ["users", "groups", "serviceaccounts"]
    verbs      = ["impersonate"]
  }

  rule {
    api_groups = ["authorization.k8s.io"]
    resources  = ["selfsubjectaccessreviews", "selfsubjectrulesreviews"]
    verbs      = ["create"]
  }

}
resource "kubernetes_cluster_role" "pods" {
  metadata {
    name = "teleport-${var.namespace}-pods"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log", "pods/exec"]
    verbs      = ["get", "watch", "list"]
  }

}

resource "kubernetes_cluster_role_binding" "impersonate" {
  metadata {
    name = "teleport-${var.namespace}-impersonate-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "teleport-${var.namespace}-impersonate"
  }

  subject {
    kind      = "Group"
    name      = "teleport-${var.namespace}"
    api_group = "rbac.authorization.k8s.io"
    namespace = var.namespace
  }
}

resource "kubernetes_role_binding" "pods" {
  metadata {
    name      = "teleport-${var.namespace}-pods-binding"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "teleport-${var.namespace}-pods"
  }

  subject {
    kind      = "Group"
    name      = "teleport-${var.namespace}"
    api_group = "rbac.authorization.k8s.io"
    namespace = var.namespace
  }
}
