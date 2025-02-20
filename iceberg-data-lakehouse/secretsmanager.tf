################################################################################
# Secrets Manager Secret (MySQL)
################################################################################

resource "aws_secretsmanager_secret" "this" {
  name       = format("%s-%s", var.application_name, "database")
  kms_key_id = aws_kms_key.this.id
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id = aws_secretsmanager_secret.this.id
  secret_string = jsonencode({
    username             = aws_db_instance.this.username
    password             = aws_db_instance.this.password
    engine               = aws_db_instance.this.engine
    host                 = aws_db_instance.this.address
    port                 = aws_db_instance.this.port
    dbname               = aws_db_instance.this.db_name
    dbInstanceIdentifier = aws_db_instance.this.identifier
    }
  )
}