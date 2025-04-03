################################################################################
# S3 Bucket
################################################################################

resource "aws_s3_bucket" "this" {
  bucket_prefix = var.application_name

  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

################################################################################
# S3 Bucket server side encryption configuration
################################################################################

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"

    }
  }
}

################################################################################
# S3 Bucket policy
################################################################################

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id

  policy = data.aws_iam_policy_document.bucket_policy.json
}


data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid    = "AllowAppStream2.0ToRetrieveObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = [
    "${aws_s3_bucket.this.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["appstream.amazonaws.com"]
    }
  }
}

################################################################################
# DBeaver Mount Script and Icon Upload
################################################################################

resource "aws_s3_object" "mount_script" {
  bucket = aws_s3_bucket.this.id
  key    = format("dbeaver/%s", "dbeaver-mount-script.sh")
  source = "${path.module}/src/dbeaver-mount-script.sh"

  source_hash = filemd5("${path.module}/src/dbeaver-mount-script.sh")
}

resource "aws_s3_object" "icon" {
  bucket = aws_s3_bucket.this.id
  key    = format("dbeaver/%s", "icon.png")
  source = "${path.module}/src/icon.png"

  source_hash = filemd5("${path.module}/src/icon.png")
}