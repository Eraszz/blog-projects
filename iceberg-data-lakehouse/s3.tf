################################################################################
# S3
################################################################################

locals {
  data_lakehouse_buckets = toset(["raw-zone", "clean-zone", "refined-zone"])
}

module "s3" {
  for_each = local.data_lakehouse_buckets

  source = "./modules/s3"

  bucket_prefix     = format("%s-%s", var.application_name, each.value)
  kms_master_key_id = aws_kms_key.this.id
}

################################################################################
# S3 Bucket for Glue Scripts
################################################################################

resource "aws_s3_bucket" "glue" {
  bucket_prefix = format("%s-%s", var.application_name, "glue")

  force_destroy = true
}

resource "aws_s3_object" "glue_init" {
  bucket = aws_s3_bucket.glue.id
  key    = "glue_init.py"
  source = "${path.module}/src/glue/glue_init.py"

  etag = filemd5("${path.module}/src/glue/glue_init.py")
}

resource "aws_s3_object" "glue_incremental" {
  bucket = aws_s3_bucket.glue.id
  key    = "glue_incremental.py"
  source = "${path.module}/src/glue/glue_incremental.py"

  etag = filemd5("${path.module}/src/glue/glue_incremental.py")
}

resource "aws_s3_object" "glue_consolidate" {
  bucket = aws_s3_bucket.glue.id
  key    = "glue_consolidate.py"
  source = "${path.module}/src/glue/glue_consolidate.py"

  etag = filemd5("${path.module}/src/glue/glue_consolidate.py")
}