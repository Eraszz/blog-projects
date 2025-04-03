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

variable "initial_database_name" {
  type        = string
  description = "Name of the initial RDS database"
}

variable "user_email_address" {
  type        = string
  description = "Email of the AppStream 2.0 User"
}

variable "user_first_name" {
  type        = string
  description = "First Name of the AppStream 2.0 User"
}

variable "user_last_name" {
  type        = string
  description = "Last Name of the AppStream 2.0 User"
}

variable "appstream_fleet_name" {
  type        = string
  description = "Name of the AppStream Fleet"
}

variable "vpc_cidr_block" {
  description = "CIDR of vpc"
  type        = string
}

variable "public_subnets" {
  description = "Map of public subnets that should be created"
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
}

variable "private_subnets" {
  description = "Map of private subnets that should be created"
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
}