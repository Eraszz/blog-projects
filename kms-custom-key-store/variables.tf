variable "application_name" {
  description = "Name of the application"
  type        = string
}

variable "key_store_password" {
  type        = string
  description = "Password for the CloudHSM custom key store"
  sensitive   = true
}

variable "kms_user_password" {
  type        = string
  description = "Password for the CloudHSM KMS User"
  sensitive   = true
}

variable "public_ip" {
  description = "Public IP used to access the RDS database. IMPORTANT: In CIDR notation needed."
  type = string
}

variable "key_name" {
  description = "Name of the key used for SSH access to CloudHSM."
  type = string
}