resource "aws_apigatewayv2_api" "api_gateway" {
  name          = "image-processor-api-${terraform.workspace}"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type"]
    max_age       = 300
  }
}
