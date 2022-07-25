output "event_bus_name" {
  description = "Name of the event bus."
  value = module.eventbridge.eventbridge_bus_name
}

output "event_bus_role" {
  description = "Name of the event bus IAM role."
  value = module.eventbridge.eventbridge_role_name
}

output "lambda_bucket_name" {
  description = "Name of the S3 bucket used to store function code."
  value = aws_s3_bucket.lambda_bucket.id
}

output "lambda_function_name" {
  description = "Name of the Lambda function."
  value = aws_lambda_function.orders.function_name
}

output "base_url" {
  description = "Base URL for API Gateway stage."
  value = aws_apigatewayv2_stage.lambda.invoke_url
}
