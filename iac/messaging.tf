
resource "aws_sqs_queue" "image_dlq" {
  name = "image-processor-${terraform.workspace}-image-dlq"

  message_retention_seconds = 1209600

  sqs_managed_sse_enabled = true

  tags = {
    Name = "image-processor-image-dlq-${terraform.workspace}"
  }
}

resource "aws_sqs_queue" "image_queue" {
  name = "image-processor-${terraform.workspace}-image-queue"

  fifo_queue = false

  visibility_timeout_seconds = 360

  message_retention_seconds = 86400

  receive_wait_time_seconds = 20

  sqs_managed_sse_enabled = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.image_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name = "image-processor-image-queue-${terraform.workspace}"
  }
}

resource "aws_sqs_queue_policy" "image_queue" {
  queue_url = aws_sqs_queue.image_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3SendMessage"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.image_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.images.arn
          }
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

output "image_queue_arn" {
  value = aws_sqs_queue.image_queue.arn
}

output "image_queue_url" {
  value = aws_sqs_queue.image_queue.id
}

output "image_dlq_arn" {
  value = aws_sqs_queue.image_dlq.arn
}
