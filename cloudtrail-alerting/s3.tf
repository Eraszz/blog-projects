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
      kms_master_key_id = aws_kms_key.this.arn
      sse_algorithm     = "aws:kms"
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
    sid    = "AWSCloudTrailAclCheck20150319"
    effect = "Allow"
    actions = [
      "s3:GetBucketAcl"
    ]
    resources = [
      aws_s3_bucket.this.arn
    ]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"

      values = [
        format("arn:aws:cloudtrail:%s:%s:trail/%s", data.aws_region.current.name, data.aws_caller_identity.current.account_id, var.application_name)
      ]
    }
  }

  statement {
    sid    = "AWSCloudTrailWrite20150319"
    effect = "Allow"
    actions = [
      "s3:PutObject"
    ]
    resources = [
      format("%s/AWSLogs/%s/*", aws_s3_bucket.this.arn, data.aws_caller_identity.current.account_id)
    ]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"

      values = [
        format("arn:aws:cloudtrail:%s:%s:trail/%s", data.aws_region.current.name, data.aws_caller_identity.current.account_id, var.application_name)
      ]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"

      values = [
        "bucket-owner-full-control"
      ]
    }
  }
}
