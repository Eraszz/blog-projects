################################################################################
# DMS Source and Target
################################################################################

resource "aws_dms_endpoint" "source" {
  #database_name = aws_db_instance.this.db_name
  endpoint_id   = format("%s-%s", var.application_name, "source")
  endpoint_type = "source"
  engine_name   = "mysql"

  secrets_manager_arn             = aws_secretsmanager_secret_version.this.arn
  secrets_manager_access_role_arn = aws_iam_role.dms.arn
}

resource "aws_dms_s3_endpoint" "target" {
  endpoint_id             = format("%s-%s", var.application_name, "target")
  endpoint_type           = "target"
  bucket_name             = module.s3["raw-zone"].id
  service_access_role_arn = aws_iam_role.dms.arn

  encryption_mode                   = "SSE_KMS"
  server_side_encryption_kms_key_id = aws_kms_key.this.arn
  add_column_name                   = true
  include_op_for_full_load          = true
}

################################################################################
# DMS Replication Task
################################################################################

resource "aws_dms_replication_config" "this" {
  replication_config_identifier = var.application_name
  resource_identifier           = var.application_name
  replication_type              = "full-load-and-cdc"
  source_endpoint_arn           = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn           = aws_dms_s3_endpoint.target.endpoint_arn

  replication_settings = jsonencode({
    Logging = {
      EnableLogging = true
      LogComponents = [{
        Id       = "SOURCE_UNLOAD"
        Severity = "LOGGER_SEVERITY_DEFAULT"
        }, {
        Id       = "TARGET_LOAD"
        Severity = "LOGGER_SEVERITY_DEFAULT"
        }, {
        Id       = "SOURCE_CAPTURE"
        Severity = "LOGGER_SEVERITY_DEFAULT"
        }, {
        Id       = "TARGET_APPLY"
        Severity = "LOGGER_SEVERITY_DEFAULT"
        }, {
        Id       = "TASK_MANAGER"
        Severity = "LOGGER_SEVERITY_DEFAULT"
      }]
    },
    ErrorBehavior = {
      FailOnNoTablesCaptured = false
    }
  })



  table_mappings = jsonencode({
    rules = flatten([for database, tables in var.database_replication_structure : [
      for table in tables : {
        object-locator = {
          schema-name = database
          table-name  = table
        }
        rule-action = "include"
        rule-id     = random_id.table_mapping_rules[format("%s-%s", database, table)].dec
        rule-name   = "${database}-${table}"
        rule-type   = "selection"
      }
    ]])
  })

  start_replication = false

  compute_config {
    max_capacity_units           = "1"
    min_capacity_units           = "1"
    preferred_maintenance_window = "sun:23:45-mon:00:30"
    multi_az                     = false
    vpc_security_group_ids       = [aws_security_group.database.id]
    replication_subnet_group_id  = aws_dms_replication_subnet_group.this.id
  }
}


resource "random_id" "table_mapping_rules" {
  for_each = toset(flatten([for database, tables in var.database_replication_structure : [
    for table in tables : format("%s-%s", database, table)
  ]]))
  byte_length = 1
}

################################################################################
# DMS Subnet Group
################################################################################

resource "aws_dms_replication_subnet_group" "this" {
  replication_subnet_group_id          = var.application_name
  replication_subnet_group_description = "Subnet Groups for serverless replicaiton task"
  subnet_ids                           = data.aws_subnets.default.ids

  depends_on = [
    aws_iam_role.dms_vpc_role
  ]
}


################################################################################
# DMS role
################################################################################

resource "aws_iam_role" "dms" {
  name = format("%s-%s", var.application_name, "dms")

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "dms.amazonaws.com",
            "dms.eu-central-1.amazonaws.com",
            "dms-data-migrations.amazonaws.com"
          ]
        }
        Condition = {
          "StringEquals" = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        } }

      },
    ]
  })
}

data "aws_iam_policy_document" "dms" {
  statement {
    sid = "SecretsManagerAccess"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      aws_secretsmanager_secret.this.arn
    ]
  }

  statement {
    sid = "KmsAccess"
    actions = [
      "kms:Encrypt",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo",
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]

    resources = [
      aws_kms_key.this.arn
    ]
  }

  statement {
    sid = "KmsDescribe"
    actions = [
      "kms:DescribeKey"
    ]

    resources = [
      aws_kms_key.this.arn
    ]
  }

  statement {
    sid = "KmsListAliases"
    actions = [
      "kms:ListAliases"
    ]

    resources = [
      "*"
    ]
  }

  statement {
    sid = "S3ObjectAccess"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObjectTagging",
      "s3:DeleteObject"
    ]

    resources = [
      "${module.s3["raw-zone"].arn}/*"
    ]
  }

  statement {
    sid = "S3ListAccess"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning"
    ]

    resources = [
      "${module.s3["raw-zone"].arn}"
    ]
  }
}

################################################################################
# DMS AWS Permissions
################################################################################


resource "aws_iam_policy" "dms" {
  name   = format("%s-%s", var.application_name, "dms")
  policy = data.aws_iam_policy_document.dms.json
}

resource "aws_iam_role_policy_attachment" "dms" {
  role       = aws_iam_role.dms.name
  policy_arn = aws_iam_policy.dms.arn
}

################################################################################
# Create DMS IAM Roles dms-vpc-role and dms-cloudwatch-logs-role
################################################################################

resource "aws_iam_role" "dms_vpc_role" {
  name = "dms-vpc-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "dms.amazonaws.com"
          ]
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dms_vpc_role" {
  role       = aws_iam_role.dms_vpc_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

resource "aws_iam_role" "dms_cloudwatch_logs_role" {
  name = "dms-cloudwatch-logs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "dms.amazonaws.com"
          ]
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dms_vpc_management_role" {
  role       = aws_iam_role.dms_cloudwatch_logs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
}
