resource "aws_apigatewayv2_api" "public_apigateway" {
  name          = "${local.stack_name}-public"
  description   = "External API for handling order processing requests"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.public_apigateway.id

  name        = "brewbar"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

# configure api gateway to use the orders lambda
resource "aws_apigatewayv2_integration" "orders" {
  api_id = aws_apigatewayv2_api.public_apigateway.id

  integration_uri    = aws_lambda_function.orders.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

# map HTTP GET request to a target: lambda 
resource "aws_apigatewayv2_route" "orders" {
  api_id = aws_apigatewayv2_api.public_apigateway.id

  route_key = "GET /orders"
  target    = "integrations/${aws_apigatewayv2_integration.orders.id}"
}

# define a log group to store access logs for the aws_apigatewayv2_stage.lambda API Gateway stage
resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/apigateway/${aws_apigatewayv2_api.public_apigateway.name}"

  retention_in_days = 30
}

# give API Gateway permission to invoke your lambda function. This is configured as a resource based 
# policy on the lambda function
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.orders.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.public_apigateway.execution_arn}/*/*"
}
