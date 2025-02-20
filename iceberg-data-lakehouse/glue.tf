locals {

  glue_crawler_raw_zone_map = merge([
    for database, tables in var.database_replication_structure : {
      for table in tables : format("raw-zone-%s-%s", database, table) => {
        table_prefix = "${database}_"
        path         = format("s3://%s/%s/%s", module.s3["raw-zone"].id, database, table)
      }
    }
  ]...)

  iceberg_consolidated_table_name = "iceberg_consolidated_table"
}

################################################################################
# Glue Database
################################################################################

resource "aws_glue_catalog_database" "this" {
  name = replace(var.application_name, "-", "_")
}

################################################################################
# Glue Raw Crawler
################################################################################

resource "aws_glue_crawler" "raw" {
  for_each = local.glue_crawler_raw_zone_map

  database_name = aws_glue_catalog_database.this.name
  name          = each.key
  role          = aws_iam_role.glue_cralwer.arn
  table_prefix  = each.value.table_prefix

  s3_target {
    path = each.value.path
  }

  lake_formation_configuration {
    use_lake_formation_credentials = true
  }

  depends_on = [
    terraform_data.dependencies
  ]
}
################################################################################
# Glue Crawler role
################################################################################

resource "aws_iam_role" "glue_cralwer" {
  name = format("%s-%s", var.application_name, "glue-crawler")

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_cralwer_service_role" {
  role       = aws_iam_role.glue_cralwer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

data "aws_iam_policy_document" "glue_cralwer_access" {
  statement {
    actions = [
      "s3:GetObject"
    ]

    resources = [for k, v in module.s3 : "${v.arn}/*"]
  }

  statement {
    actions = [
      "lakeformation:GetDataAccess"
    ]
    resources = ["*"]
  }


}

resource "aws_iam_policy" "glue_cralwer_access" {
  name   = format("%s-%s", aws_iam_role.glue_cralwer.name, "s3-access")
  policy = data.aws_iam_policy_document.glue_cralwer_access.json
}

resource "aws_iam_role_policy_attachment" "glue_cralwer_access" {
  role       = aws_iam_role.glue_cralwer.name
  policy_arn = aws_iam_policy.glue_cralwer_access.arn
}

################################################################################
# Glue Init Job
################################################################################

resource "aws_glue_job" "glue_init" {
  name                    = format("%s-%s", var.application_name, "glue-init")
  role_arn                = aws_iam_role.glue.arn
  glue_version            = "5.0"
  number_of_workers       = 2
  worker_type             = "G.1X"
  job_run_queuing_enabled = true
  security_configuration  = aws_glue_security_configuration.this.name

  command {
    script_location = format("s3://%s/%s", aws_s3_bucket.glue.id, aws_s3_object.glue_init.key)
  }

  default_arguments = {
    "--job-language"                              = "python"
    "--continuous-log-logGroup"                   = aws_cloudwatch_log_group.glue_init.name
    "--enable-continuous-cloudwatch-log"          = true
    "--enable-continuous-log-filter"              = true
    "--enable-glue-datacatalog"                   = true
    "--enable-job-insights"                       = true
    "--enable--lakeformation-fine-grained-access" = true
    "--enable-metrics"                            = true
    "--datalake-formats"                          = "iceberg"
    "--clean_zone_bucket_name"                    = module.s3["clean-zone"].id
    "--glue_database_name"                        = aws_glue_catalog_database.this.name
    "--catalog_name"                              = "glue_catalog"
  }

  depends_on = [
    terraform_data.dependencies
  ]
}

resource "aws_cloudwatch_log_group" "glue_init" {
  name = format("/aws/glue/%s-%s", var.application_name, "glue-init")

  retention_in_days = 30
}

################################################################################
# Glue Incremental Job
################################################################################

resource "aws_glue_job" "glue_incremental" {
  name                    = format("%s-%s", var.application_name, "glue-incremental")
  role_arn                = aws_iam_role.glue.arn
  glue_version            = "4.0"
  number_of_workers       = 2
  worker_type             = "G.1X"
  job_run_queuing_enabled = true
  security_configuration  = aws_glue_security_configuration.this.name

  command {
    script_location = format("s3://%s/%s", aws_s3_bucket.glue.id, aws_s3_object.glue_incremental.key)
  }

  default_arguments = {
    "--job-language"                              = "python-3"
    "--continuous-log-logGroup"                   = aws_cloudwatch_log_group.glue_incremental.name
    "--enable-continuous-cloudwatch-log"          = true
    "--enable-continuous-log-filter"              = true
    "--enable-glue-datacatalog"                   = true
    "--enable-job-insights"                       = true
    "--enable--lakeformation-fine-grained-access" = true
    "--enable-metrics"                            = true
    "--datalake-formats"                          = "iceberg"
    "--clean_zone_bucket_name"                    = module.s3["clean-zone"].id
    "--glue_database_name"                        = aws_glue_catalog_database.this.name
    "--catalog_name"                              = "glue_catalog"
    "--conf"                                      = "spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions"
    "--enable-glue-datacatalog"                   = true
    "library-set"                                 = "analytics"
  }

  depends_on = [
    terraform_data.dependencies
  ]
}

resource "aws_cloudwatch_log_group" "glue_incremental" {
  name = format("/aws/glue/%s-%s", var.application_name, "glue-incremental")

  retention_in_days = 30
}

################################################################################
# Glue Consolidate Job
################################################################################

resource "aws_glue_workflow" "glue_consolidate" {
  name = format("%s-%s", var.application_name, "glue-consolidate")
}

resource "aws_glue_trigger" "glue_consolidate" {
  name          = format("%s-%s", var.application_name, "glue-consolidate")
  type          = "ON_DEMAND"
  workflow_name = aws_glue_workflow.glue_consolidate.name

  actions {
    job_name = aws_glue_job.glue_consolidate.name
  }

  event_batching_condition {
    batch_size = 1
  } 
}

resource "aws_glue_job" "glue_consolidate" {
  name                    = format("%s-%s", var.application_name, "glue-consolidate")
  role_arn                = aws_iam_role.glue.arn
  glue_version            = "4.0"
  number_of_workers       = 2
  worker_type             = "G.1X"
  job_run_queuing_enabled = true
  security_configuration  = aws_glue_security_configuration.this.name

  command {
    script_location = format("s3://%s/%s", aws_s3_bucket.glue.id, aws_s3_object.glue_consolidate.key)
  }

  default_arguments = {
    "--job-language"                              = "python-3"
    "--continuous-log-logGroup"                   = aws_cloudwatch_log_group.glue_consolidate.name
    "--enable-continuous-cloudwatch-log"          = true
    "--enable-continuous-log-filter"              = true
    "--enable-glue-datacatalog"                   = true
    "--enable-job-insights"                       = true
    "--enable--lakeformation-fine-grained-access" = true
    "--enable-metrics"                            = true
    "--datalake-formats"                          = "iceberg"
    "--refined_zone_bucket_name"                  = module.s3["refined-zone"].id
    "--glue_database_name"                        = aws_glue_catalog_database.this.name
    "--catalog_name"                              = "glue_catalog"
    "--iceberge_consolidated_table_name"          = local.iceberg_consolidated_table_name
    "--sales_table_name"                          = "iceberg_bookstoredb_sales"
    "--customer_table_name"                       = "iceberg_bookstoredb_customer"
    "--book_table_name"                           = "iceberg_bookstoredb_book"
    "--conf"                                      = "spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions"
    "--enable-glue-datacatalog"                   = true
    "library-set"                                 = "analytics"
  }

  depends_on = [
    terraform_data.dependencies
  ]
}

resource "aws_cloudwatch_log_group" "glue_consolidate" {
  name = format("/aws/glue/%s-%s", var.application_name, "glue-consolidate")

  retention_in_days = 30
}

################################################################################
# Glue role
################################################################################

resource "aws_iam_role" "glue" {
  name = format("%s-%s", var.application_name, "glue")

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

data "aws_iam_policy_document" "glue" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = concat([for k, v in module.s3 : "${v.arn}/*"], ["${aws_s3_bucket.glue.arn}/*"])
  }

  statement {
    actions = [
      "lakeformation:GetDataAccess"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "iam:PassRole"
    ]
    resources = [aws_iam_role.glue.arn]
  }

  statement {
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt"
    ]

    resources = [aws_kms_key.this.arn]
  }

}

resource "aws_iam_policy" "glue" {
  name   = format("%s-%s", aws_iam_role.glue.name, "s3-access")
  policy = data.aws_iam_policy_document.glue.json
}

resource "aws_iam_role_policy_attachment" "glue" {
  role       = aws_iam_role.glue.name
  policy_arn = aws_iam_policy.glue.arn
}

################################################################################
# Glue Security Configuration
################################################################################

resource "aws_glue_security_configuration" "this" {
  name = var.application_name

  encryption_configuration {
    cloudwatch_encryption {
      cloudwatch_encryption_mode = "DISABLED"
    }

    job_bookmarks_encryption {
      job_bookmarks_encryption_mode = "DISABLED"
    }

    s3_encryption {
      kms_key_arn        = aws_kms_key.this.arn
      s3_encryption_mode = "SSE-KMS"
    }
  }
}
