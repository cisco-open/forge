data "aws_iam_policy_document" "ec2_tags" {
  statement {
    actions = [
      "ec2:CreateTags"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ARN"
      values   = ["$${ec2:SourceInstanceARN}"]
    }
    condition {
      test     = "ForAllValues:StringLike"
      variable = "aws:TagKeys"
      values = [
        "ghr:repository",
        "ghr:run_id",
        "ghr:workflow",
        "ghr:job",
        "ghr:commit",
        "ghr:ref",
        "ghr:run_attempt",
        "ghr:run_number",
        "ghr:actor",
      ]
    }
  }
}

# Define the actual IAM policy for EC2 tags
resource "aws_iam_policy" "ec2_tags" {
  name        = "${var.runner_configs.prefix}-policy-for-ec2-tags"
  description = "Policy that allows EC2 instances to create tags on themselves."
  policy      = data.aws_iam_policy_document.ec2_tags.json

  tags     = var.tenant_configs.tags
  tags_all = var.tenant_configs.tags
}
