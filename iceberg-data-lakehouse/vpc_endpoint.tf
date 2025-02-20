################################################################################
# VPC Endpoints
################################################################################

resource "aws_vpc_endpoint" "secretsmanager" {
  service_name      = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
  vpc_endpoint_type = "Interface"

  vpc_id             = data.aws_vpc.default.id
  security_group_ids = [aws_security_group.vpc_endpoint.id]
  subnet_ids         = data.aws_subnets.default.ids

  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "s3" {
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  vpc_id = data.aws_vpc.default.id
}

resource "aws_vpc_endpoint_route_table_association" "this" {
  for_each = toset(data.aws_route_tables.default.ids)

  route_table_id  = each.value
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

################################################################################
# Endpoint Security Group
################################################################################

resource "aws_security_group" "vpc_endpoint" {
  name   = format("%s-%s", var.application_name, "vpc-endpoint")
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "vpc_endpoint_ingress" {
  security_group_id = aws_security_group.vpc_endpoint.id

  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = local.default_subnet_cidrs
}

