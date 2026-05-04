resource "aws_apigatewayv2_api" "api_gateway" {
  name          = "api-gateway-${terraform.workspace}"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type"]
    max_age       = 300
  }
}


resource "aws_apigatewayv2_integration" "upload_lambda" {
  api_id           = aws_apigatewayv2_api.api_gateway.id
  integration_type = "AWS_PROXY"

  connection_type        = "INTERNET"
  description            = "Upload file to S3 bucket"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.upload_lambda.invoke_arn
  timeout_milliseconds   = 30000
  payload_format_version = "2.0"
}
