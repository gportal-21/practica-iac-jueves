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
  source_dir  = "${path.module}/../src/upload-lambda"
  output_path = "${path.module}/build/upload-lambda.zip"
}

data "archive_file" "crop_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src/crop-lambda"
  output_path = "${path.module}/build/crop-lambda.zip"
}
