# Amazon API Gateway Version 2 resources are used for creating and deploying WebSocket and HTTP APIs,
# therefore for creating and deploying REST APIs, Amazon API Gateway Version 1 resources are used
resource "aws_api_gateway_rest_api" "internal_events_api" {
  name          = "${local.stack_name}-internal-events-api"
  description   = "Internal API for validating and enriching events before routing them to event bridge"
}

resource "aws_api_gateway_resource" "delivered_resource" {
  rest_api_id = aws_api_gateway_rest_api.internal_events_api.id
  parent_id   = aws_api_gateway_rest_api.internal_events_api.root_resource_id
  path_part   = "delivery"
}

# resource "aws_api_gateway_resource" "order" {
#   rest_api_id = aws_api_gateway_rest_api.internal_events_api.id
#   parent_id   = aws_api_gateway_rest_api.internal_events_api.root_resource_id
#   path_part   = "order"
# }

resource "aws_api_gateway_method" "delivered_method" {
  rest_api_id   = aws_api_gateway_rest_api.internal_events_api.id
  resource_id   = aws_api_gateway_resource.delivered_resource.id
  http_method   = "POST"
  authorization = "NONE"
  request_parameters   = {
      "method.request.header.Content-Type" = false
      "method.request.header.X-Amz-Target" = false
  }
  request_validator_id  = aws_api_gateway_request_validator.delivered_validator.id
  request_models        = {
    "application/json" = aws_api_gateway_model.order_delivered_model.name
  }
}

resource "aws_api_gateway_request_validator" "delivered_validator" {
  name                        = "delivered-validator"
  rest_api_id                 = aws_api_gateway_rest_api.internal_events_api.id
  validate_request_body       = true
  validate_request_parameters = true
}

resource "aws_api_gateway_model" "order_delivered_model" {
  rest_api_id  = aws_api_gateway_rest_api.internal_events_api.id
  name         = "orderDeliveredSchema"
  description  = "Order Delivered JSON schema"
  content_type = "application/json"

  schema = <<EOF
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "type": "object",
    "properties": {
        "ordersDelivered": {
            "type": "array",
            "items": [
                {
                    "type": "object",
                    "properties": {
                        "orderId": {
                            "type": "string"
                        },
                        "address": {
                            "$ref" : "#/definitions/Address"
                        }
                    },
                    "required": [
                        "orderId",
                        "address"
                    ]
                }
            ]
        }
    },
    "required": [
        "ordersDelivered"
    ],
    "definitions": {
        "Address": {
            "type": "object",
            "required": ["line2","city","zipCode","country"],
            "properties": {
                "line2": {
                    "type": "string"
                },
                "city": {
                    "type": "string"
                },
                "zipCode": {
                    "type": "string"
                },
                "state": {
                    "type": "string"
                },
                "country": {
                    "type": "string"
                }
            }
        }
    }
}
EOF
}

resource "aws_api_gateway_method_response" "delivered_response_200" {
    rest_api_id         = aws_api_gateway_rest_api.internal_events_api.id
    resource_id         = aws_api_gateway_resource.delivered_resource.id
    http_method         = aws_api_gateway_method.delivered_method.http_method
    response_models     = {
        "application/json" = "Empty"
    }
    response_parameters = {}
    status_code         = "200"
}

resource "aws_api_gateway_integration" "delivered_integration" {
  rest_api_id             = aws_api_gateway_rest_api.internal_events_api.id
  resource_id             = aws_api_gateway_resource.delivered_resource.id
  http_method             = aws_api_gateway_method.delivered_method.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:events:action/PutEvents"
  passthrough_behavior    = "WHEN_NO_TEMPLATES"
  credentials             = aws_iam_role.internal_events_api_role.arn

  timeout_milliseconds = 29000

  request_parameters = {
    "integration.request.header.X-Authorization" = "'static'"
  }

  # Transforms the incoming JSON request payload to EventBridge event
  request_templates = {
        "application/json" = <<-EOT
            #set($context.requestOverride.header.X-Amz-Target = "AWSEvents.PutEvents")
            #set($context.requestOverride.header.Content-Type = "application/x-amz-json-1.1")            
            #set($inputRoot = $input.path('$')) 
            { 
              "Entries": [
                #foreach($elem in $inputRoot.ordersDelivered)
                {
                  "Detail": "$util.escapeJavaScript($elem).replaceAll("\\'","'")",
                  "DetailType": "orderDelivered",
                  "EventBusName": "${module.eventbridge.eventbridge_bus_name}",
                  "Source":"delivery"
                }#if($foreach.hasNext),#end
                #end
              ]
            }
        EOT
  }
}

resource "aws_api_gateway_integration_response" "delivered_response" {
  rest_api_id          = aws_api_gateway_rest_api.internal_events_api.id
  resource_id          = aws_api_gateway_resource.delivered_resource.id
  http_method         = aws_api_gateway_method.delivered_method.http_method
  response_templates  = {
      "application/json" = <<-EOT
          #set($inputRoot = $input.path('$'))
        {
        }
      EOT
  }
  status_code         = aws_api_gateway_method_response.delivered_response_200.status_code
  depends_on = [aws_api_gateway_integration.delivered_integration]
}

resource "aws_api_gateway_deployment" "delivered" {
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
      aws_api_gateway_resource.delivered_resource.id,
      aws_api_gateway_method.delivered_method.id,
      aws_api_gateway_integration.delivered_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "events" {
  deployment_id = aws_api_gateway_deployment.delivered.id
  rest_api_id   = aws_api_gateway_rest_api.internal_events_api.id
  stage_name    = "events"
}

resource "aws_api_gateway_method_settings" "delivered" {
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
