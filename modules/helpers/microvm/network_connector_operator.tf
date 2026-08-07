data "aws_iam_policy_document" "lambda_assume_operator_role" {
  statement {
    sid     = "LambdaNetworkConnectorService"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "operator" {
  name               = "forge-microvm-network-operator-${var.aws_region}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_operator_role.json
  tags               = local.all_security_tags
  tags_all           = local.all_security_tags
}

resource "aws_iam_role_policy_attachment" "operator" {
  role       = aws_iam_role.operator.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSLambdaNetworkConnectorOperatorPolicy"
}
