# Role assumed by Forge Runners
data "aws_iam_policy_document" "assume_role_for_forge_runners" {
  # Allows us to access S3, SecretsManager immediately when we SSH into a runner VM.
  statement {
    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com",
        "s3.amazonaws.com",
      ]
    }
  }

  # Allow GH runners to assume dedicated role.
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]
    principals {
      type        = "AWS"
      identifiers = var.forge.runner_roles
    }
  }
}

# Dedicated role. Allow it to be assumed.
resource "aws_iam_role" "role_for_forge_runners" {
  name                 = "role_for_forge_runners"
  assume_role_policy   = data.aws_iam_policy_document.assume_role_for_forge_runners.json
  max_session_duration = 21600 # Allow role to last for up to 6 hours.
  tags                 = local.all_security_tags
  tags_all             = local.all_security_tags
}
