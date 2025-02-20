################################################################################
# S3 Bucket variables
################################################################################

variable "bucket_prefix" {
  description = "Bucket prefix"
  type        = string
}

variable "kms_master_key_id" {
  description = "KMS key ID for encryption"
  type        = string
}