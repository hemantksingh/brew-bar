resource "aws_api_gateway_rest_api" "public_orders_api" {
  name          = "${local.stack_name}-orders-api"
  description   = "Public API for creating and managing brew bar orders"
}

resource "aws_api_gateway_resource" "orders_resource" {
  rest_api_id = aws_api_gateway_rest_api.public_orders_api.id
  parent_id   = aws_api_gateway_rest_api.public_orders_api.root_resource_id
  path_part   = "orders"
}

resource "aws_api_gateway_method" "orders_method" {
  rest_api_id   = aws_api_gateway_rest_api.public_orders_api.id
  resource_id   = aws_api_gateway_resource.orders_resource.id
  http_method   = "POST"
  authorization = "NONE"
  request_parameters   = {
      "method.request.header.Content-Type" = false
      "method.request.header.X-Amz-Target" = false
  }
  request_validator_id  = aws_api_gateway_request_validator.orders_validator.id
  request_models        = {
    "application/json" = aws_api_gateway_model.orders_model.name
  }
}

resource "aws_api_gateway_request_validator" "orders_validator" {
  name                        = "orders-validator"
  rest_api_id                 = aws_api_gateway_rest_api.public_orders_api.id
  validate_request_body       = true
  validate_request_parameters = true
}

resource "aws_api_gateway_model" "orders_model" {
  rest_api_id  = aws_api_gateway_rest_api.public_orders_api.id
  name         = "ordersSchema"
  description  = "New orders JSON schema"
  content_type = "application/json"

  schema = <<EOF
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "type": "object",
    "required": ["firstName", "lastName", "phoneNumber", "address"],
    "properties": {
        "firstName": {
            "type": "string"
        },
        "lastName": {
            "type": "string"
        },
        "phoneNumber": {
            "type": "string"
        },
        "address": {
            "$ref": "#/definitions/Address"
        }
    },
    "definitions": {
        "Address": {
            "type": "object",
            "required": ["line1", "line2", "city", "postcode","country"],
            "properties": {
                "line1": {
                    "type": "string"
                },
                "line2": {
                    "type": "string"
                },
                "city": {
                    "type": "string"
                },
                "postcode": {
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

resource "aws_api_gateway_method_response" "orders_response_200" {
    rest_api_id         = aws_api_gateway_rest_api.public_orders_api.id
    resource_id         = aws_api_gateway_resource.orders_resource.id
    http_method         = aws_api_gateway_method.orders_method.http_method
    response_models     = {
        "application/json" = "Empty"
    }
    response_parameters = {}
    status_code         = "200"
}

resource "aws_api_gateway_integration" "orders_integration" {
  rest_api_id             = aws_api_gateway_rest_api.public_orders_api.id
  resource_id             = aws_api_gateway_resource.orders_resource.id
  http_method             = aws_api_gateway_method.orders_method.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.orders.invoke_arn
  passthrough_behavior    = "WHEN_NO_TEMPLATES"
}

resource "aws_api_gateway_integration_response" "orders_response" {
  rest_api_id          = aws_api_gateway_rest_api.public_orders_api.id
  resource_id          = aws_api_gateway_resource.orders_resource.id
  http_method         = aws_api_gateway_method.orders_method.http_method
  response_templates  = {
      "application/json" = <<-EOT
          #set($inputRoot = $input.path('$'))
        {
        }
      EOT
  }
  status_code         = aws_api_gateway_method_response.orders_response_200.status_code
  depends_on = [aws_api_gateway_integration.orders_integration]
}

resource "aws_api_gateway_deployment" "orders" {
  rest_api_id = aws_api_gateway_rest_api.public_orders_api.id

  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.orders_resource.id,
      aws_api_gateway_method.orders_method.id,
      aws_api_gateway_integration.orders_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "brewbar" {
  deployment_id = aws_api_gateway_deployment.orders.id
  rest_api_id   = aws_api_gateway_rest_api.public_orders_api.id
  stage_name    = "brewbar"
}

resource "aws_api_gateway_method_settings" "orders" {
  rest_api_id = aws_api_gateway_rest_api.public_orders_api.id
  stage_name  = aws_api_gateway_stage.brewbar.stage_name
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

resource "aws_lambda_permission" "public_apigateway_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.orders.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.public_orders_api.execution_arn}/*/*"
}