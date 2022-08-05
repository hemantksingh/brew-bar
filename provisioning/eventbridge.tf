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

resource "aws_cloudwatch_log_group" "orders_events" {
  name = "/aws/events/${module.eventbridge.eventbridge_bus_name}"
  retention_in_days = 30
  tags = {
    Environment = var.environment
    Application = var.application
  }
}
