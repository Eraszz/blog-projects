locals {
  lakeformation_database_permissions = {
    crawler = {
      principal     = aws_iam_role.glue_cralwer.arn
      permissions   = ["CREATE_TABLE"]
      database_name = aws_glue_catalog_database.this.name
    }

    glue_init = {
      principal     = aws_iam_role.glue.arn
      permissions   = ["CREATE_TABLE", "DESCRIBE"]
      database_name = aws_glue_catalog_database.this.name
    }
  }

  lakeformation_data_location_permissions = {
    crawler = {
      principal         = aws_iam_role.glue_cralwer.arn
      permissions       = ["DATA_LOCATION_ACCESS"]
      data_location_arn = aws_lakeformation_resource.this["raw-zone"].arn
    }

    glue_init_raw_zone = {
      principal         = aws_iam_role.glue.arn
      permissions       = ["DATA_LOCATION_ACCESS"]
      data_location_arn = aws_lakeformation_resource.this["raw-zone"].arn
    }

    glue_init_clean_zone = {
      principal         = aws_iam_role.glue.arn
      permissions       = ["DATA_LOCATION_ACCESS"]
      data_location_arn = aws_lakeformation_resource.this["clean-zone"].arn
    }

    glue_init_refined_zone = {
      principal         = aws_iam_role.glue.arn
      permissions       = ["DATA_LOCATION_ACCESS"]
      data_location_arn = aws_lakeformation_resource.this["refined-zone"].arn
    }
  }

  lakeformation_table_permissions = {
    glue_init = {
      principal     = aws_iam_role.glue.arn
      permissions   = ["SELECT", "INSERT", "ALTER", "DESCRIBE"]
      database_name = aws_glue_catalog_database.this.name
      wildcard      = true
    }
  }
}

################################################################################
# Lakeformation Settings
################################################################################

resource "aws_lakeformation_data_lake_settings" "this" {
  admins = [
    aws_iam_role.lakeformation_admin.arn,
    data.aws_iam_session_context.current.issuer_arn
  ]
}

resource "aws_lakeformation_resource" "this" {
  for_each = module.s3

  arn      = each.value.arn
  role_arn = aws_iam_role.lakeformation_resource.arn
}

################################################################################
# Lakeformation Permissions
################################################################################

resource "aws_lakeformation_permissions" "admin_database" {
  principal   = data.aws_iam_session_context.current.issuer_arn
  permissions = ["ALL"]

  database {
    name = aws_glue_catalog_database.this.name
  }

  depends_on = [aws_lakeformation_data_lake_settings.this]
}

resource "aws_lakeformation_permissions" "admin_table" {
  principal   = data.aws_iam_session_context.current.issuer_arn
  permissions = ["ALL"]

  table {
    database_name = aws_glue_catalog_database.this.name
    wildcard      = true
  }

  depends_on = [aws_lakeformation_data_lake_settings.this]
}

resource "aws_lakeformation_permissions" "database" {
  for_each = local.lakeformation_database_permissions

  principal   = each.value.principal
  permissions = each.value.permissions

  database {
    name = each.value.database_name
  }

  depends_on = [aws_lakeformation_permissions.admin_database]
}

resource "aws_lakeformation_permissions" "data_location" {
  for_each = local.lakeformation_data_location_permissions

  principal   = each.value.principal
  permissions = each.value.permissions

  data_location {
    arn = each.value.data_location_arn
  }

  depends_on = [aws_lakeformation_permissions.admin_database]
}

resource "aws_lakeformation_permissions" "table" {
  for_each = local.lakeformation_table_permissions

  principal   = each.value.principal
  permissions = each.value.permissions

  table {
    database_name = each.value.database_name
    wildcard      = each.value.wildcard
  }

  depends_on = [aws_lakeformation_permissions.admin_table]
}

################################################################################
# Lakeformation Admin role
################################################################################

resource "aws_iam_role" "lakeformation_admin" {
  name = format("%s-%s", var.application_name, "lakeformation-admin")

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      },
    ]
  })
}

################################################################################
# Lakeformation AWS Permissions => https://docs.aws.amazon.com/lake-formation/latest/dg/initial-lf-config.html#setup-change-cat-settings
################################################################################

resource "aws_iam_role_policy_attachment" "lakeformation_data_admin" {
  role       = aws_iam_role.lakeformation_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLakeFormationDataAdmin"
}

resource "aws_iam_role_policy_attachment" "glue_console_full_access" {
  role       = aws_iam_role.lakeformation_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess"
}

resource "aws_iam_role_policy_attachment" "cloudWatch_logs_readonly_access" {
  role       = aws_iam_role.lakeformation_admin.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "athena_full_access" {
  role       = aws_iam_role.lakeformation_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonAthenaFullAccess"
}

data "aws_iam_policy_document" "lakeformation_slr" {
  statement {
    actions = [
      "iam:CreateServiceLinkedRole"
    ]

    resources = [
      "*"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["lakeformation.amazonaws.com"]
    }
  }

  statement {
    actions = [
      "iam:PutRolePolicy"
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/lakeformation.amazonaws.com/AWSServiceRoleForLakeFormationDataAccess"
    ]
  }
}

resource "aws_iam_policy" "lakeformation_slr" {
  name   = format("%s-%s", aws_iam_role.lakeformation_admin.name, "slr")
  policy = data.aws_iam_policy_document.lakeformation_slr.json
}

resource "aws_iam_role_policy_attachment" "lakeformation_slr" {
  role       = aws_iam_role.lakeformation_admin.name
  policy_arn = aws_iam_policy.lakeformation_slr.arn
}


################################################################################
# Lakeformation Resource Role
################################################################################

resource "aws_iam_role" "lakeformation_resource" {
  name = format("%s-%s", var.application_name, "lakeformation-resource")

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lakeformation.amazonaws.com"
        }
      },
    ]
  })
}

data "aws_iam_policy_document" "lakeformation_resource" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [for k, v in module.s3 : "${v.arn}/*"]
  }

  statement {
    actions = [
      "s3:ListBucket"
    ]

    resources = [for k, v in module.s3 : v.arn]
  }

  statement {
    actions = [
      "s3:ListAllMyBuckets"
    ]

    resources = ["arn:aws:s3:::*"]
  }

  statement {
    actions = [
      "kms:Decrypt"
    ]
    resources = [aws_kms_key.this.arn]
  }
}

resource "aws_iam_policy" "lakeformation_resource" {
  name   = format("%s-%s", aws_iam_role.lakeformation_resource.name, "s3-access")
  policy = data.aws_iam_policy_document.lakeformation_resource.json
}

resource "aws_iam_role_policy_attachment" "lakeformation_resource" {
  role       = aws_iam_role.lakeformation_resource.name
  policy_arn = aws_iam_policy.lakeformation_resource.arn
}