locals {
  public_subnet_ids   = [for k, v in aws_subnet.public : v.id]
  public_subnet_cidrs = [for k, v in aws_subnet.public : v.cidr_block]

  private_subnet_ids   = [for k, v in aws_subnet.private : v.id]
  private_subnet_cidrs = [for k, v in aws_subnet.private : v.cidr_block]
}

################################################################################
# VPC
################################################################################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true

  tags = {
    Name = var.application_name
  }
}


################################################################################
# Public Subnets
################################################################################

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id = aws_vpc.this.id

  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = format("public-%s-%s", var.application_name, each.value.availability_zone)
  }
}


################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}


################################################################################
# Public Route table
################################################################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = format("public-%s", var.application_name)
  }
}

resource "aws_route" "public" {

  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id

}


################################################################################
# Public Route Association
################################################################################

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}


################################################################################
# Private subnets
################################################################################

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id = aws_vpc.this.id

  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = {
    Name = format("private-%s-%s", var.application_name, each.value.availability_zone)
  }
}


################################################################################
# EIP for NAT Gateway
################################################################################

resource "aws_eip" "nat" {
  for_each = aws_subnet.private
  domain   = "vpc"
}


################################################################################
# NAT Gateway
################################################################################

resource "aws_nat_gateway" "this" {
  for_each = aws_subnet.private

  subnet_id     = aws_subnet.public[each.key].id
  allocation_id = aws_eip.nat[each.key].id

  tags = {
    Name = format("private-%s-%s", var.application_name, each.value.availability_zone)
  }
}


################################################################################
# Private route tables
################################################################################

resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.this.id

  tags = {
    Name = format("private-%s-%s", var.application_name, each.value.availability_zone)
  }
}

resource "aws_route" "nat" {
  for_each = aws_subnet.private

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.key].id
}


################################################################################
# Private route associations
################################################################################

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}