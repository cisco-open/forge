data "aws_iam_policy_document" "ecr_repository_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:GetAuthorizationToken",
      "ecr:ListImages"
    ]

    principals {
      type        = "AWS"
      identifiers = var.ecr_access_account_ids
    }
  }
}

resource "aws_ecr_repository_policy" "repository_policy" {
  for_each = toset(var.repository_names)

  repository = each.value
  policy     = data.aws_iam_policy_document.ecr_repository_policy.json
}
