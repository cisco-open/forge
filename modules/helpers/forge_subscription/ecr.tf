locals {
  ecr_repo_region_pairs = flatten([
    for region in var.forge.ecr_repositories.regions : [
      for name in var.forge.ecr_repositories.names : {
        region = region
        name   = name
      }
    ]
  ])
}

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
      identifiers = var.forge.ecr_repositories.ecr_access_account_ids
    }
  }
}

resource "aws_ecr_repository_policy" "repository_policy" {
  for_each = {
    for pair in local.ecr_repo_region_pairs : "${pair.region}/${pair.name}" => pair
  }
  provider = aws.by_region[each.value.region]

  repository = each.value.name
  policy     = data.aws_iam_policy_document.ecr_repository_policy.json
}
