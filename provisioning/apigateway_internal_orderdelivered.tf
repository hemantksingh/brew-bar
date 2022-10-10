resource "aws_api_gateway_resource" "orderdelivered_resource" {
  rest_api_id = aws_api_gateway_rest_api.internal_events_api.id
  parent_id   = aws_api_gateway_rest_api.internal_events_api.root_resource_id
  path_part   = "order-delivered"
}

resource "aws_api_gateway_method" "orderdelivered_method" {
  rest_api_id   = aws_api_gateway_rest_api.internal_events_api.id
  resource_id   = aws_api_gateway_resource.orderdelivered_resource.id
  http_method   = "POST"
  authorization = "NONE"
  request_parameters   = {
      "method.request.header.Content-Type" = false
      "method.request.header.X-Amz-Target" = false
  }
  request_validator_id  = aws_api_gateway_request_validator.orderdelivered_validator.id
  request_models        = {
    "application/json" = aws_api_gateway_model.orderdelivered_model.name
  }
}

resource "aws_api_gateway_request_validator" "orderdelivered_validator" {
  name                        = "orderdelivered-validator"
  rest_api_id                 = aws_api_gateway_rest_api.internal_events_api.id
  validate_request_body       = true
  validate_request_parameters = true
}

resource "aws_api_gateway_model" "orderdelivered_model" {
  rest_api_id  = aws_api_gateway_rest_api.internal_events_api.id
  name         = "OrderDeliveredSchema"
  description  = "Order Delivered JSON schema"
  content_type = "application/json"

  schema = <<EOF
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "type": "object",
    "required": ["orderId", "firstName", "lastName", "phoneNumber", "dispatchedOn", "address"],
    "properties": {
        "orderId": {
            "type": "string"
        },
        "firstName": {
            "type": "string"
        },
        "lastName": {
            "type": "string"
        },
        "phoneNumber": {
            "type": "string"
        },
        "dispatchedOn": {
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

resource "aws_api_gateway_method_response" "orderdelivered_response_200" {
    rest_api_id         = aws_api_gateway_rest_api.internal_events_api.id
    resource_id         = aws_api_gateway_resource.orderdelivered_resource.id
    http_method         = aws_api_gateway_method.orderdelivered_method.http_method
    response_models     = {
        "application/json" = "Empty"
    }
    response_parameters = {}
    status_code         = "200"
}

resource "aws_api_gateway_integration" "orderdelivered_integration" {
  rest_api_id             = aws_api_gateway_rest_api.internal_events_api.id
  resource_id             = aws_api_gateway_resource.orderdelivered_resource.id
  http_method             = aws_api_gateway_method.orderdelivered_method.http_method
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
                {
                  "Detail": "$util.escapeJavaScript($input.json('$')).replaceAll("\\'","'")",
                  "DetailType": "OrderDelivered",
                  "EventBusName": "${module.eventbridge.eventbridge_bus_name}",
                  "Source":"brewbar.delivery"
                }
              ]
            }
        EOT
  }
}

resource "aws_api_gateway_integration_response" "orderdelivered_event_response" {
  rest_api_id          = aws_api_gateway_rest_api.internal_events_api.id
  resource_id          = aws_api_gateway_resource.orderdelivered_resource.id
  http_method         = aws_api_gateway_method.orderdelivered_method.http_method
  response_templates  = {
      "application/json" = <<-EOT
          #set($inputRoot = $input.path('$'))
        {
        }
      EOT
  }
  status_code = aws_api_gateway_method_response.orderdelivered_response_200.status_code
  depends_on = [aws_api_gateway_integration.orderdelivered_integration]
}