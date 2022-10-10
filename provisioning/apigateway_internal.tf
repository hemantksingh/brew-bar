# Amazon API Gateway Version 2 resources are used for creating and deploying WebSocket and HTTP APIs,
# therefore for creating and deploying REST APIs, Amazon API Gateway Version 1 resources are used
resource "aws_api_gateway_rest_api" "internal_events_api" {
  name          = "${local.stack_name}-internal-events-api"
  description   = "Internal API for validating and enriching events before routing them to event bridge"
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.internal_events_api.id

  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.orderdelivered_resource.id,
      aws_api_gateway_method.orderdelivered_method.id,
      aws_api_gateway_integration.orderdelivered_integration.id,
      aws_api_gateway_model.orderdelivered_model.id,
      aws_api_gateway_resource.orderplaced_resource.id,
      aws_api_gateway_method.orderplaced_method.id,
      aws_api_gateway_integration.orderplaced_integration.id,
      aws_api_gateway_model.orderplaced_model.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "events" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.internal_events_api.id
  stage_name    = "events"
}

resource "aws_api_gateway_method_settings" "settings" {
  rest_api_id = aws_api_gateway_rest_api.internal_events_api.id
  stage_name  = aws_api_gateway_stage.events.stage_name
  method_path = "*/*"

  settings {
    data_trace_enabled = true # full request and response logs
    metrics_enabled = true # enable Detailed CloudWatch Metrics
    # Based on https://docs.aws.amazon.com/apigateway/latest/developerguide/view-cloudwatch-log-events-in-cloudwatch-console.html 
    # the logs can be viewed in the API-Gateway-Execution-Logs_{rest-api-id}/{stage-name} log group in CloudWatch 
    logging_level   = "INFO" 

    # limit the rate of calls to prevent abuse and unwanted charges
    throttling_rate_limit  = 100
    throttling_burst_limit = 50
  }
}

# API gateway role with permissions to put events on event bridge
resource "aws_iam_role" "internal_events_api_role" {
  name = "${local.stack_name}-internal-apigateway-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
      }
    ]
  })

  permissions_boundary = data.aws_iam_policy.boundary.arn
}

resource "aws_iam_role_policy_attachment" "internal_apigateway_eventbridge_policy" {
  role       = aws_iam_role.internal_events_api_role.name
  policy_arn = aws_iam_policy.eventbridge_basic.arn
}

resource "aws_iam_role_policy_attachment" "internal_apigateway_cloudwatch_policy" {
  role       = aws_iam_role.internal_events_api_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# define the account wide CloudWatch permissions for the API Gateway per region. 
# This setting applies to all the API Gateways in the selected region.
resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = aws_iam_role.internal_events_api_role.arn
}
