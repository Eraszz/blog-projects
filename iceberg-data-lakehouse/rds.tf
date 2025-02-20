################################################################################
# MySQL RDS
################################################################################

resource "aws_db_instance" "this" {
  allocated_storage       = 20
  storage_type            = "gp3"
  backup_retention_period = 7

  db_subnet_group_name = aws_db_subnet_group.this.name
  engine               = "mysql"
  engine_version       = "8.4.3"
  identifier           = var.application_name
  db_name              = var.initial_database_name
  instance_class       = "db.t4g.micro"
  kms_key_id           = aws_kms_key.this.arn
  storage_encrypted    = true
  multi_az             = false
  skip_final_snapshot  = true

  vpc_security_group_ids = [aws_security_group.database.id]

  password = var.password_database
  username = var.username_database

  publicly_accessible = "true"
}

################################################################################
# RDS Subnet Group
################################################################################

resource "aws_db_subnet_group" "this" {
  name       = var.application_name
  subnet_ids = data.aws_subnets.default.ids
}

################################################################################
# Security Group
################################################################################

resource "aws_security_group" "database" {
  name   = format("%s-%s", var.application_name, "database")
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "ingress_self" {
  security_group_id = aws_security_group.database.id

  type      = "ingress"
  from_port = 3306
  to_port   = 3306
  protocol  = "tcp"
  self      = true
}

resource "aws_security_group_rule" "ingress_default" {
  security_group_id = aws_security_group.database.id

  type        = "ingress"
  from_port   = 3306
  to_port     = 3306
  protocol    = "tcp"
  cidr_blocks = local.default_subnet_cidrs
}

resource "aws_security_group_rule" "ingress_public" {
  security_group_id = aws_security_group.database.id

  type        = "ingress"
  from_port   = 3306
  to_port     = 3306
  protocol    = "tcp"
  cidr_blocks = [var.public_ip]
}

resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.database.id

  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
