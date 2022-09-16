data "archive_file" "lambda_delivery" {
  type = "zip"

  source_dir  = "${path.module}/../delivery"
  output_path = "${path.module}/../delivery.zip"
}

resource "aws_s3_object" "lambda_delivery" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "delivery.zip"
  source = data.archive_file.lambda_delivery.output_path

  etag = filemd5(data.archive_file.lambda_delivery.output_path)
}

resource "aws_lambda_function" "delivery" {
  function_name = "${local.stack_name}-delivery"
  description = "Brew bar delivery processing"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_delivery.key

  runtime = "nodejs12.x"
  handler = "delivery.handler"

  source_code_hash = data.archive_file.lambda_delivery.output_base64sha256

  role = aws_iam_role.delivery_lambda_exec_role.arn

  environment {
    variables = {
      EVENT_BUS_NAME = module.eventbridge.eventbridge_bus_name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.delivery_lambda,
  ]
}

# give Event bridge permission to invoke your lambda function. This is configured as a resource based 
# policy on the lambda function
resource "aws_lambda_permission" "event_bridge" {
  statement_id  = "AllowExecutionFromEventBridgeOrders"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delivery.function_name
  principal     = "events.amazonaws.com"
  source_arn = module.eventbridge.eventbridge_rule_arns["orders"]
}

resource "aws_iam_role" "delivery_lambda_exec_role" {
  name = "${local.stack_name}-delivery-role"

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

resource "aws_iam_role_policy_attachment" "delivery_lambda_execution_policy" {
  role       = aws_iam_role.delivery_lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Give lambda permission to put events on eventbridge
resource "aws_iam_role_policy_attachment" "delivery_lambda_events" {
  role       = aws_iam_role.delivery_lambda_exec_role.name
  policy_arn = aws_iam_policy.eventbridge_basic.arn
}

resource "aws_cloudwatch_log_group" "delivery_lambda" {
  name = "/aws/lambda/${local.stack_name}-delivery"

  retention_in_days = 30
}

resource "aws_iam_policy" "delivery_lambda_logging" {
  name        = "${aws_lambda_function.delivery.function_name}-cloudwatch"
  path        = "/"
  description = "IAM policy for logging from the delivery lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Effect = "Allow"
      Resource = aws_cloudwatch_log_group.delivery_lambda.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "delivery_lambda_logs_policy" {
  role       = aws_iam_role.delivery_lambda_exec_role.name
  policy_arn = aws_iam_policy.delivery_lambda_logging.arn
}