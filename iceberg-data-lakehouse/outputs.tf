output "rds_endpoint" {
  description = "Endpoint of the RDS database"
  value = aws_db_instance.this.endpoint
}