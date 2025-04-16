variable "application_name" {
  description = "Name of the application"
  type        = string
}

variable "iam_events" {
  description = "IAM events that should be monitored via EventBridge"
  type        = list(string)
}

variable "sns_endpoint" {
  description = "Email used for the SNS subscription"
  type        = string
}