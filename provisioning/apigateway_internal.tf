# Amazon API Gateway Version 2 resources are used for creating and deploying WebSocket and HTTP APIs,
# therefore Amazon API Gateway Version 1 resources are used for creating and deploying REST APIs
resource "aws_api_gateway_rest_api" "internal_events_api" {
  name          = "${local.stack_name}-internal-events-api"
  description   = "Internal API for validating and enriching events before routing them to event bridge"
}

resource "aws_api_gateway_resource" "delivery_resource" {
  rest_api_id = aws_api_gateway_rest_api.internal_events_api.id
  parent_id   = aws_api_gateway_rest_api.internal_events_api.root_resource_id
  path_part   = "delivery"
}

# resource "aws_api_gateway_resource" "order" {
#   rest_api_id = aws_api_gateway_rest_api.internal_events_api.id
#   parent_id   = aws_api_gateway_rest_api.internal_events_api.root_resource_id
#   path_part   = "order"
# }

resource "aws_api_gateway_method" "delivery_method" {
  rest_api_id   = aws_api_gateway_rest_api.internal_events_api.id
  resource_id   = aws_api_gateway_resource.delivery_resource.id
  http_method   = "POST"
  authorization = "NONE"
  request_parameters   = {
      "method.request.header.Content-Type" = false
      "method.request.header.X-Amz-Target" = false
  }
}

resource "aws_api_gateway_method_response" "response_200" {
    rest_api_id         = aws_api_gateway_rest_api.internal_events_api.id
    resource_id         = aws_api_gateway_resource.delivery_resource.id
    http_method         = aws_api_gateway_method.delivery_method.http_method
    response_models     = {
        "application/json" = "Empty"
    }
    response_parameters = {}
    status_code         = "200"
}

resource "aws_api_gateway_integration" "delivery_integration" {
  rest_api_id             = aws_api_gateway_rest_api.internal_events_api.id
  resource_id             = aws_api_gateway_resource.delivery_resource.id
  http_method             = aws_api_gateway_method.delivery_method.http_method
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

resource "aws_api_gateway_integration_response" "this" {
  rest_api_id          = aws_api_gateway_rest_api.internal_events_api.id
  resource_id          = aws_api_gateway_resource.delivery_resource.id
  http_method         = aws_api_gateway_method.delivery_method.http_method
  response_templates  = {
      "application/json" = <<-EOT
          #set($inputRoot = $input.path('$'))
        {
        }
      EOT
  }
  status_code         = aws_api_gateway_method_response.response_200.status_code
  depends_on = [aws_api_gateway_integration.delivery_integration]
}

resource "aws_api_gateway_deployment" "this" {
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
      aws_api_gateway_resource.delivery_resource.id,
      aws_api_gateway_method.delivery_method.id,
      aws_api_gateway_integration.delivery_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.internal_events_api.id
  stage_name    = "dev"
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

resource "aws_iam_role_policy_attachment" "apigateway_policy" {
  role       = aws_iam_role.internal_events_api_role.name
  policy_arn = aws_iam_policy.eventbridge_basic.arn
}