resource "aws_s3_bucket" "lambda_bucket" {
  bucket = local.stack_name
  # acl           = "private"
  force_destroy = true
}

data "archive_file" "lambda_orders" {
  type = "zip"

  source_dir  = "${path.module}/../orders"
  output_path = "${path.module}/../orders.zip"
}

resource "aws_s3_object" "lambda_orders" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "orders.zip"
  source = data.archive_file.lambda_orders.output_path

  etag = filemd5(data.archive_file.lambda_orders.output_path)
}