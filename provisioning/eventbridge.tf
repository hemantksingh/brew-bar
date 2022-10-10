module "eventbridge" {
  source  = "terraform-aws-modules/eventbridge/aws"
  version = "1.14.1"

  bus_name = local.stack_name
  attach_cloudwatch_policy = true

  cloudwatch_target_arns = [
    aws_cloudwatch_log_group.orders_events.arn
  ]

  rules = {
    orders = {
      description   = "Capture all order data"
      event_pattern = jsonencode({ "source" : ["brewbar.orders"] })
      enabled       = true
    }
  }
  
  targets = {
    orders = [
      {
        name = "log-orders-to-cloudwatch"
        arn  = aws_cloudwatch_log_group.orders_events.arn
      },
      {
        name = "send orders to delivery"
        arn = aws_lambda_function.delivery.arn
      }
    ]
  }
#   policy = ""
#   policy_json = ""
#   role_description = ""
#   role_name = ""
#   role_path =""
    role_permissions_boundary = data.aws_iam_policy.boundary.arn
  
  # insert the 6 required variables here

  tags = {
    Environment = var.environment
    Application = var.application
  }
}

resource "aws_schemas_discoverer" "this" {
  source_arn  = module.eventbridge.eventbridge_bus_arn
  description = "Auto discover event schemas"
}

# This policy can be used to give permissions to other resources (e.g. lambda, apigateway)
# to put events on eventbridge
resource "aws_iam_policy" "eventbridge_basic" {
  name        = "AWSEventBridgeBasic"
  path        = "/"
  description = "Allows putting events and describing rules on the specified event bus"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "events:PutEvents",
        "events:DescribeRule"
      ]
      Effect = "Allow"
      Sid    = ""
      Resource = module.eventbridge.eventbridge_bus_arn
      }
    ]
  })
}

# route order events put on EB to cloud watch
resource "aws_cloudwatch_log_group" "orders_events" {
  name = "/aws/events/${module.eventbridge.eventbridge_bus_name}"
  retention_in_days = 7
  tags = {
    Environment = var.environment
    Application = var.application
  }
}

resource "null_resource" "post_orders_config" {
  depends_on = [module.eventbridge]
  
  provisioner "local-exec" {
      command = "rm -f .env && printf \"AWS_REGION=$AWS_REGION\nEVENT_BUS_NAME=$EVENT_BUS_NAME\" >> .env"
      working_dir = "${path.module}/../orders"

      environment = {
        AWS_REGION = var.region
        EVENT_BUS_NAME = module.eventbridge.eventbridge_bus_name
      }
    }
}

resource "null_resource" "post_delivery_config" {
  depends_on = [module.eventbridge]
  
  provisioner "local-exec" {
      command = "rm -f .env && printf \"AWS_REGION=$AWS_REGION\nEVENT_BUS_NAME=$EVENT_BUS_NAME\" >> .env"
      working_dir = "${path.module}/../delivery"

      environment = {
        AWS_REGION = var.region
        EVENT_BUS_NAME = module.eventbridge.eventbridge_bus_name
      }
    }
}