/*
################################################################################
# AppStream Fleet Association
################################################################################

resource "aws_appstream_fleet_stack_association" "this" {
  fleet_name = var.appstream_fleet_name
  stack_name = aws_appstream_stack.this.name
}
*/

################################################################################
# Image Builder
################################################################################

resource "aws_appstream_image_builder" "this" {
  name                           = var.application_name
  display_name                   = var.application_name
  enable_default_internet_access = false
  image_name                     = "AppStream-AmazonLinux2-02-11-2025"
  instance_type                  = "stream.standard.large"
  iam_role_arn                   = aws_iam_role.image_builder.arn

  vpc_config {
    subnet_ids         = [local.private_subnet_ids[0]]
    security_group_ids = [aws_security_group.image_builder.id]
  }
}

################################################################################
# AppStream Stack and User Creation
################################################################################

resource "aws_appstream_stack" "this" {
  name = var.application_name

  storage_connectors {
    connector_type = "HOMEFOLDERS"
  }
}

resource "aws_appstream_user" "this" {
  authentication_type = "USERPOOL"
  user_name           = var.user_email_address
  first_name          = var.user_first_name
  last_name           = var.user_last_name
}

resource "aws_appstream_user_stack_association" "this" {
  authentication_type = aws_appstream_user.this.authentication_type
  stack_name          = aws_appstream_stack.this.name
  user_name           = aws_appstream_user.this.user_name
}

################################################################################
# Security Group
################################################################################

resource "aws_security_group" "image_builder" {
  name   = format("%s-%s", var.application_name, "image-builder")
  vpc_id = aws_vpc.this.id
}

resource "aws_security_group_rule" "image_builder_egress" {
  security_group_id = aws_security_group.image_builder.id

  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}


################################################################################
# AppStream Image Builder Role
################################################################################

resource "aws_iam_role" "image_builder" {
  name = format("%s-%s", var.application_name, "image-builder")

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "appstream.amazonaws.com"
        }
      },
    ]
  })
}

data "aws_iam_policy_document" "image_builder" {
  statement {
    actions = [
      "kms:DescribeKey",
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:Encrypt",
    ]

    resources = [
      aws_kms_key.this.arn
    ]
  }

  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "image_builder" {
  name   = format("%s-%s", var.application_name, "image-builder")
  policy = data.aws_iam_policy_document.image_builder.json
}

resource "aws_iam_role_policy_attachment" "image_builder" {
  role       = aws_iam_role.image_builder.name
  policy_arn = aws_iam_policy.image_builder.arn
}
