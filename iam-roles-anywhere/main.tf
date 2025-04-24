resource "aws_rolesanywhere_trust_anchor" "this" {
  name    = var.application_name
  enabled = true
  source {
    source_data {
      x509_certificate_data = file("${path.module}/certs/rootCA.pem")
    }
    source_type = "CERTIFICATE_BUNDLE"
  }
}

resource "aws_rolesanywhere_profile" "this" {

  name    = var.application_name
  enabled = true

  role_arns = [aws_iam_role.this.arn]
}

################################################################################
# Lambda Permissions
################################################################################

resource "aws_iam_role" "this" {
  name = var.application_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession",
          "sts:SetSourceIdentity"
        ]
        Effect = "Allow"
        Principal = {
          Service = "rolesanywhere.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}