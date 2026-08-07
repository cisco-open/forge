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

# IAM reports role and policy writes before they are consistently available to
# Lambda. The Network Connector resource validates the role only once during
# creation, so wait before allowing CloudFormation to create any connector.
resource "time_sleep" "operator_role_propagation" {
  depends_on = [aws_iam_role_policy_attachment.operator]

  create_duration = "30s"

  triggers = {
    operator_role_unique_id    = aws_iam_role.operator.unique_id
    operator_trust_policy_sha1 = sha1(aws_iam_role.operator.assume_role_policy)
  }

  lifecycle {
    replace_triggered_by = [aws_iam_role_policy_attachment.operator]
  }
}
