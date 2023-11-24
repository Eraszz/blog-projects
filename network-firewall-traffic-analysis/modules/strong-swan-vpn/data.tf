################################################################################
# Get VPC information
################################################################################

data "aws_vpc" "this" {
  id = var.vpc_id
}

################################################################################
# Get Private subnet information
################################################################################

data "aws_subnet" "private" {
  id = var.private_subnet_id
}

################################################################################
# Get Public subnet information
################################################################################

data "aws_subnet" "public" {
  id = var.public_subnet_id
}