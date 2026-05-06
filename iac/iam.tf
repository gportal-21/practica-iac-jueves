data "aws_iam_policy_document" "lambda_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "upload_lambda" {
  name               = "upload-lambda-role-${terraform.workspace}"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json

  tags = {
    Name = "upload-lambda-role-${terraform.workspace}"
  }
}

resource "aws_iam_role_policy_attachment" "upload_basic" {
  role       = aws_iam_role.upload_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "upload_vpc" {
  role       = aws_iam_role.upload_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "upload_s3" {
  statement {
    sid       = "AllowPutObjectInUploadsPrefix"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.images.arn}/uploads/*"]
  }
}

resource "aws_iam_role_policy" "upload_s3" {
  name   = "upload-lambda-s3-policy"
  role   = aws_iam_role.upload_lambda.id
  policy = data.aws_iam_policy_document.upload_s3.json
}

resource "aws_iam_role" "crop_lambda" {
  name               = "crop-lambda-role-${terraform.workspace}"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json

  tags = {
    Name = "crop-lambda-role-${terraform.workspace}"
  }
}

resource "aws_iam_role_policy_attachment" "crop_basic" {
  role       = aws_iam_role.crop_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "crop_vpc" {
  role       = aws_iam_role.crop_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "crop_combined" {
  statement {
    sid       = "AllowGetObjectFromUploads"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.images.arn}/uploads/*"]
  }

  statement {
    sid       = "AllowPutObjectInProcessed"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.images.arn}/processed/*"]
  }

  statement {
    sid    = "AllowSQSConsumer"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ChangeMessageVisibility"
    ]
    resources = [aws_sqs_queue.image_queue.arn]
  }
}

resource "aws_iam_role_policy" "crop_combined" {
  name   = "crop-lambda-combined-policy"
  role   = aws_iam_role.crop_lambda.id
  policy = data.aws_iam_policy_document.crop_combined.json
}
