variable "permissions_boundary_policy" {
  type        = string
  description = "Permissions boundary policy to be used for the lambda execution role creation"
}

resource "aws_lambda_function" "orders" {
  function_name = "hk-playground-orders"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_orders.key

  runtime = "nodejs12.x"
  handler = "orders.handler"

  source_code_hash = data.archive_file.lambda_orders.output_base64sha256

  role = aws_iam_role.lambda_exec_role.arn
}

resource "aws_cloudwatch_log_group" "orders" {
  name = "/aws/lambda/${aws_lambda_function.orders.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "hk_playground_orders_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })

  permissions_boundary = data.aws_iam_policy.boundary.arn
}

data "aws_caller_identity" "current" {
}

data "aws_iam_policy" "boundary" {
  arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.permissions_boundary_policy}"
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
