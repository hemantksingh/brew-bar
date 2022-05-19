variable "region" {
  type    = string
}

variable "stack_prefix" {
  type    = string
}

variable "permissions_boundary_policy" {
  type        = string
  description = "Permissions boundary policy to be used for the role creation"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "application" {
  type    = string
  default = "brewbar"
}

provider "aws" {
  region = var.region

  # Make it faster by skipping something
  skip_get_ec2_platforms      = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
}


module "eventbridge" {
  source  = "terraform-aws-modules/eventbridge/aws"
  version = "1.14.1"

  bus_name = local.stack_name
  attach_cloudwatch_policy = true

  cloudwatch_target_arns = [
    aws_cloudwatch_log_group.orders.arn
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
        arn  = aws_cloudwatch_log_group.orders.arn
      }
    ]
  }
#   policy = ""
#   policy_json = ""
#   role_description = ""
#   role_name = ""
#   role_path =""
    role_permissions_boundary = local.role_permissions_boundary
  
  # insert the 6 required variables here

  tags = {
    Environment = var.environment
    Application = var.application
  }
}

resource "random_pet" "this" {
  length = 2
}

resource "aws_cloudwatch_log_group" "orders" {
  name = "/aws/events/${local.stack_name}"

  tags = {
    Environment = var.environment
    Application = var.application
  }
}

locals {
  role_permissions_boundary = data.aws_iam_policy.boundary.arn
  stack_name = "${var.stack_prefix}-${random_pet.this.id}"
}

data "aws_caller_identity" "current" {
}

data "aws_iam_policy" "boundary" {
  arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.permissions_boundary_policy}"
}