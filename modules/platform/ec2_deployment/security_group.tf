# Allow the lambda to egress to any destination via any protocol.
resource "aws_security_group" "gh_runner_lambda_egress" {
  name   = "${var.runner_configs.prefix}-gh-runner-lambda-egress-all"
  vpc_id = var.network_configs.lambda_vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tenant_configs.tags,
    {
      Name = "${var.runner_configs.prefix}-gh-runner-lambda-egress-all"
    }
  )

  tags_all = var.tenant_configs.tags
}
