resource "random_password" "webhook_token" {
  length  = 40
  special = false
}

resource "aws_apigatewayv2_api" "splunk" {
  name          = "${var.name_prefix}-api"
  description   = "Splunk alert webhook receiver for stuck Forge workflow jobs"
  protocol_type = "HTTP"
  tags          = local.all_security_tags
  tags_all      = local.all_security_tags
}

resource "aws_apigatewayv2_integration" "dispatcher" {
  api_id           = aws_apigatewayv2_api.splunk.id
  integration_type = "AWS_PROXY"
  integration_uri  = module.dispatcher.lambda_function_arn
}

resource "aws_apigatewayv2_route" "splunk_webhook" {
  #checkov:skip=CKV_AWS_309:Public Splunk webhook route validates the generated path token in the Lambda integration.
  api_id    = aws_apigatewayv2_api.splunk.id
  route_key = "POST /splunk/{token}"
  target    = "integrations/${aws_apigatewayv2_integration.dispatcher.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.splunk.id
  name        = "$default"
  auto_deploy = true
  tags        = local.all_security_tags
  tags_all    = local.all_security_tags

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      ip                      = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      httpMethod              = "$context.httpMethod"
      path                    = "$context.path"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      protocol                = "$context.protocol"
      responseLength          = "$context.responseLength"
      responseLatency         = "$context.responseLatency"
      integrationStatus       = "$context.integrationStatus"
      integrationErrorMessage = "$context.integrationErrorMessage"
      errorMessage            = "$context.error.message"
      errorResponseType       = "$context.error.responseType"
    })
  }
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/apigateway/${var.name_prefix}"
  retention_in_days = var.logging_retention_in_days
  tags              = local.all_security_tags
  tags_all          = local.all_security_tags
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.dispatcher.lambda_function_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.splunk.execution_arn}/*/*"
}
