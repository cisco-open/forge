data "aws_iam_policy_document" "lambda_service_assume_role" {
  statement {
    sid    = "LambdaMicrovmService"
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "build" {
  name               = "forge-microvm-build-${var.aws_region}"
  assume_role_policy = data.aws_iam_policy_document.lambda_service_assume_role.json
  tags               = local.all_security_tags
  tags_all           = local.all_security_tags
}
