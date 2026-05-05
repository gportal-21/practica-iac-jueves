resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"

  tags = {
    Name = "image-processor-vpc-${terraform.workspace}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "image-processor-igw-${terraform.workspace}"
  }
}

#############################################################

# Public subnets
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "image-processor-public-a-${terraform.workspace}"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "image-processor-public-b-${terraform.workspace}"
  }
}


# Private subnets
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "image-processor-private-a-${terraform.workspace}"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-2b"

  tags = {
    Name = "image-processor-private-b-${terraform.workspace}"
  }
}

#############################################################

# Route tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "image-processor-rt-public-${terraform.workspace}"
  }
}

# Route for public subnets
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "image-processor-rt-private-a-${terraform.workspace}"
  }
}

resource "aws_route" "private_a_nat" {
  route_table_id         = aws_route_table.private_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_a.id
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "image-processor-rt-private-b-${terraform.workspace}"
  }
}

resource "aws_route" "private_b_nat" {
  route_table_id         = aws_route_table.private_b.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_b.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}

#############################################################

# EIP
resource "aws_eip" "nat_a" {
  domain = "vpc"

  tags = {
    Name = "image-processor-eip-nat-a-${terraform.workspace}"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_eip" "nat_b" {
  domain = "vpc"

  tags = {
    Name = "image-processor-eip-nat-b-${terraform.workspace}"
  }

  depends_on = [aws_internet_gateway.igw]
}

# NAT Gateways
resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "image-processor-nat-a-${terraform.workspace}"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.public_b.id

  tags = {
    Name = "image-processor-nat-b-${terraform.workspace}"
  }

  depends_on = [aws_internet_gateway.igw]
}

# SG
resource "aws_security_group" "upload_lambda" {
  name        = "image-processor-sg-upload-lambda-${terraform.workspace}"
  description = "SG para upload-lambda: outbound HTTPS a VPC Endpoints"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "image-processor-sg-upload-lambda-${terraform.workspace}"
  }
}

resource "aws_security_group" "crop_lambda" {
  name        = "image-processor-sg-crop-lambda-${terraform.workspace}"
  description = "SG para crop-lambda: outbound HTTPS a VPC Endpoints"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "image-processor-sg-crop-lambda-${terraform.workspace}"
  }
}

resource "aws_security_group" "vpce_sqs" {
  name        = "image-processor-sg-vpce-sqs-${terraform.workspace}"
  description = "SG para SQS Interface VPC Endpoint: inbound HTTPS desde Lambdas"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "image-processor-sg-vpce-sqs-${terraform.workspace}"
  }
}

# Egress rules
resource "aws_vpc_security_group_egress_rule" "upload_to_vpce_sqs" {
  security_group_id            = aws_security_group.upload_lambda.id
  referenced_security_group_id = aws_security_group.vpce_sqs.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS to SQS VPC Endpoint"
}

resource "aws_vpc_security_group_egress_rule" "crop_to_vpce_sqs" {
  security_group_id            = aws_security_group.crop_lambda.id
  referenced_security_group_id = aws_security_group.vpce_sqs.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS to SQS VPC Endpoint"
}

data "aws_prefix_list" "s3" {
  name = "com.amazonaws.us-east-2.s3"
}

resource "aws_vpc_security_group_egress_rule" "upload_to_s3" {
  security_group_id = aws_security_group.upload_lambda.id
  prefix_list_id    = data.aws_prefix_list.s3.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS to S3 (via VPC Gateway Endpoint)"
}

resource "aws_vpc_security_group_egress_rule" "crop_to_s3" {
  security_group_id = aws_security_group.crop_lambda.id
  prefix_list_id    = data.aws_prefix_list.s3.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS to S3 (via VPC Gateway Endpoint)"
}

# Ingress rules
resource "aws_vpc_security_group_ingress_rule" "vpce_sqs_from_upload" {
  security_group_id            = aws_security_group.vpce_sqs.id
  referenced_security_group_id = aws_security_group.upload_lambda.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS from upload-lambda"
}

resource "aws_vpc_security_group_ingress_rule" "vpce_sqs_from_crop" {
  security_group_id            = aws_security_group.vpce_sqs.id
  referenced_security_group_id = aws_security_group.crop_lambda.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS from crop-lambda"
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-2.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private_a.id,
    aws_route_table.private_b.id,
  ]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3ReadWriteOnImagesBucket"
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::image-processor-${terraform.workspace}-images-*",
          "arn:aws:s3:::image-processor-${terraform.workspace}-images-*/*"
        ]
      }
    ]
  })

  tags = {
    Name = "image-processor-vpce-s3-${terraform.workspace}"
  }
}

resource "aws_vpc_endpoint" "sqs" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-2.sqs"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
  ]

  security_group_ids = [
    aws_security_group.vpce_sqs.id,
  ]

  private_dns_enabled = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSQSAccessToImageQueue"
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility",
          "sqs:SendMessage"
        ]
        Resource = [
          "arn:aws:sqs:us-east-2:*:image-processor-${terraform.workspace}-image-queue",
          "arn:aws:sqs:us-east-2:*:image-processor-${terraform.workspace}-image-dlq"
        ]
      }
    ]
  })

  tags = {
    Name = "image-processor-vpce-sqs-${terraform.workspace}"
  }
}
