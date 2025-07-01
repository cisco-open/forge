data "aws_iam_policy_document" "assume_role" {
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

  dynamic "statement" {
    for_each = var.scale_set_type == "dind" && var.migrate_arc_cluster == false ? [1] : []

    content {
      effect = "Allow"

      principals {
        type = "Federated"
        identifiers = [
          var.oidc_provider_arn
        ]
      }

      actions = ["sts:AssumeRoleWithWebIdentity"]

      condition {
        test     = "StringEquals"
        variable = "${regex("^arn:aws:iam::\\d+:oidc-provider/(.+)$", var.oidc_provider_arn)[0]}:sub"
        values = [
          "system:serviceaccount:${var.namespace}:${var.service_account}"
        ]
      }
    }
  }
}

resource "aws_iam_role" "runner_role" {
  name               = var.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags     = var.tags
  tags_all = var.tags
}

resource "aws_iam_role_policy_attachment" "runner_role_policy_attachment" {
  count      = length(var.runner_iam_role_managed_policy_arns)
  role       = aws_iam_role.runner_role.name
  policy_arn = element(var.runner_iam_role_managed_policy_arns, count.index)
}

resource "kubernetes_service_account_v1" "runner_sa" {
  count = var.migrate_arc_cluster == false ? 1 : 0
  metadata {
    name      = var.service_account
    namespace = var.namespace
  }
}

resource "aws_eks_pod_identity_association" "eks_pod_identity" {
  count           = var.migrate_arc_cluster == false ? 1 : 0
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account
  role_arn        = aws_iam_role.runner_role.arn

  tags = var.tags
}
