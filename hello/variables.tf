# Input variable definitions

variable "aws_region" {
  description = "AWS region for all resources."

  type    = string
  default = "eu-west-1"
}

variable "permissions_boundary_policy" {
  type        = string
  description = "Permissions boundary policy to be used for the role creation"
}