resource "aws_cloudwatch_log_group" "upload_lambda" {
  name              = "/aws/lambda/image-processor-upload-${terraform.workspace}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "crop_lambda" {
  name              = "/aws/lambda/image-processor-crop-${terraform.workspace}"
  retention_in_days = 14
}

data "archive_file" "upload_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src/lambda/upload-lambda"
  output_path = "${path.module}/build/upload-lambda.zip"
}

data "archive_file" "crop_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src/lambda/crop-lambda"
  output_path = "${path.module}/build/crop-lambda.zip"

  excludes = [
    "node_modules/.bin",
    "build.ps1",
  ]
}

resource "aws_lambda_function" "upload_lambda" {
  function_name = "image-processor-upload-${terraform.workspace}"
  role          = aws_iam_role.upload_lambda.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"

  filename         = data.archive_file.upload_lambda_zip.output_path
  source_code_hash = data.archive_file.upload_lambda_zip.output_base64sha256

  memory_size = 256
  timeout     = 30

  environment {
    variables = {
      S3_BUCKET     = aws_s3_bucket.images.bucket
      UPLOAD_PREFIX = "uploads/"
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.upload_lambda.id]
  }

  tags = {
    Name = "image-processor-upload-${terraform.workspace}"
  }

  depends_on = [aws_cloudwatch_log_group.upload_lambda]
}

resource "aws_lambda_function" "crop_lambda" {
  function_name = "image-processor-crop-${terraform.workspace}"
  role          = aws_iam_role.crop_lambda.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"

  filename         = data.archive_file.crop_lambda_zip.output_path
  source_code_hash = data.archive_file.crop_lambda_zip.output_base64sha256

  memory_size = 512
  timeout     = 60

  environment {
    variables = {
      S3_BUCKET        = aws_s3_bucket.images.bucket
      PROCESSED_PREFIX = "processed/"
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.crop_lambda.id]
  }

  tags = {
    Name = "image-processor-crop-${terraform.workspace}"
  }

  depends_on = [aws_cloudwatch_log_group.crop_lambda]
}

resource "aws_lambda_event_source_mapping" "sqs_to_crop" {
  event_source_arn = aws_sqs_queue.image_queue.arn
  function_name    = aws_lambda_function.crop_lambda.arn

  batch_size = 5

  function_response_types = ["ReportBatchItemFailures"]

  maximum_batching_window_in_seconds = 5

  enabled = true
}
