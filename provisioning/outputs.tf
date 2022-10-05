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

output "orders_lambda_function_name" {
  description = "Name of the Orders processing Lambda function."
  value = aws_lambda_function.orders.function_name
}

output "delivery_lambda_function_name" {
  description = "Name of the Delivery processing Lambda function."
  value = aws_lambda_function.delivery.function_name
}

output "orders_api_url" {
  description = "URL for public Orders API."
  value = aws_api_gateway_stage.brewbar.invoke_url
}

output "internal_events_api_url" {
  description = "URL for Internal Gateway events API."
  value = aws_api_gateway_stage.events.invoke_url
}