variable "region" {
  type    = string
}

variable "stack_prefix" {
  type    = string
}

variable "use_permissions_boundary" {
  type = bool
  description = "Whether use a permission boundary while creating an IAM role?"
  default = false
}

variable "permissions_boundary_policy" {
  type        = string
  description = "Permissions boundary policy to be used for the role creation"
  default = null
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

  # Make it faster by skipping checks
  skip_get_ec2_platforms      = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = false
}

resource "random_pet" "stack" {
  prefix = var.stack_prefix
  length = 2
}

locals {
  stack_name = random_pet.stack.id
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = local.stack_name
  # acl           = "private"
  force_destroy = true
}

data "aws_caller_identity" "current" {
}

data "aws_iam_policy" "boundary" {
  count = var.use_permissions_boundary ? 1: 0
  arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.permissions_boundary_policy}"
}