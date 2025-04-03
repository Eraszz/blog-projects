output "s3_bucket_name" {
  description = "Name of the S3 Bucket used to store the VHD"
  value = aws_s3_bucket.this.id
}

output "rds_endpoint" {
  description = "Endpoint of the RDS MySQL database. Needed to create a connection in DBeaver."
  value = aws_db_instance.this.endpoint
}
