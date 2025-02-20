variable "application_name" {
  description = "Name of the application"
  type        = string
}

variable "password_database" {
  type        = string
  description = "Password for the RDS database"
  sensitive   = true
}

variable "username_database" {
  type        = string
  description = "Username for the RDS database"
  sensitive   = true
}

variable "database_replication_structure" {
  type        = map(set(string))
  description = "Databases and tables to sync from RDS to S3 using DMS. Map Key is the database name and the set are the tables."
}

variable "initial_database_name" {
  type        = string
  description = "Name of the initial RDS database"
}

variable "public_ip" {
  description = "Public IP used to access the RDS database. IMPORTANT: In CIDR notation needed."
  type = string
}