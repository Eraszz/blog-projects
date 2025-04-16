resource "aws_cloudtrail" "this" {
  name           = var.application_name
  s3_bucket_name = aws_s3_bucket.this.id

  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  kms_key_id = aws_kms_key.this.arn

  depends_on = [aws_s3_bucket_policy.this]
}