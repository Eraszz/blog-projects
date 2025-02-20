/*
locals {
  quicksight_user_name = "xxxxxxxxxxxxxxxxxx"
}

resource "aws_lakeformation_permissions" "quicksight_table_access" {

  principal   = format("arn:aws:quicksight:%s:%s:user/default/%s", data.aws_region.current.name, data.aws_caller_identity.current.account_id, local.quicksight_user_name)
  permissions   = ["SELECT", "DESCRIBE"]

  table {
    database_name = aws_glue_catalog_database.this.name
    name      = local.iceberg_consolidated_table_name
  }

  depends_on = [aws_lakeformation_permissions.admin_table]
}
*/
