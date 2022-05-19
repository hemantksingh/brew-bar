terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = "~> 1.0"
}

variable "stack_prefix" {
  type    = string
}

variable "region" {
  description = "AWS region for all resources."
  type    = string
  default = "eu-west-1"
}

provider "aws" {
  region = var.region
}

resource "random_pet" "lambda_bucket_name" {
  prefix = var.stack_prefix
  length = 4
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id

#   acl           = "private"
  force_destroy = true
}

data "archive_file" "lambda_orders" {
  type = "zip"

  source_dir  = "${path.module}/../../orders"
  output_path = "${path.module}/../../orders.zip"
}

resource "aws_s3_object" "lambda_orders" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "orders.zip"
  source = data.archive_file.lambda_orders.output_path

  etag = filemd5(data.archive_file.lambda_orders.output_path)
}

