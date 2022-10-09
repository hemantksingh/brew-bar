
resource "aws_s3_object" "lambda_orders" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "orders.zip"
  source = "${path.module}/../orders.zip"

  etag = filemd5("${path.module}/../orders.zip")
}

resource "aws_lambda_function" "orders" {
  function_name = "${local.stack_name}-orders"
  description = "Brew bar orders processing"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_orders.key

  runtime = "nodejs16.x"
  handler = "orders.lambdaHandler"

  source_code_hash = filebase64sha256("${path.module}/../orders.zip")

  role = aws_iam_role.lambda_exec_role.arn

   environment {
    variables = {
      EVENT_BUS_NAME = module.eventbridge.eventbridge_bus_name
      INTERNAL_EVENTS_API_URI = aws_api_gateway_stage.events.invoke_url
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.orders_lambda,
  ]
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "${local.stack_name}-orders-role"

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

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

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

resource "aws_iam_role_policy_attachment" "lambda_events" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.eventbridge_basic.arn
}

resource "aws_cloudwatch_log_group" "orders_lambda" {
  name = "/aws/lambda/${local.stack_name}-orders"

  retention_in_days = 7
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}