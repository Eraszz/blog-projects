output "rolesanywhere_profile_arn" {
  description = "Amazon Resource Name (ARN) of the Profile."
  value       = aws_rolesanywhere_profile.this.arn
}

output "rolesanywhere_trust_anchor_arn" {
  description = "Amazon Resource Name (ARN) of the Trust Anchor."
  value       = aws_rolesanywhere_trust_anchor.this.arn
}

output "iam_role_arn" {
  description = "Amazon Resource Name (ARN) of the IAM Role."
  value       = aws_iam_role.this.arn
}


