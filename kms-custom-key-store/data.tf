################################################################################
# Get default VPC
################################################################################

data "aws_vpc" "default" {
  default = true
}

################################################################################
# Get List of private Subnet IDs
################################################################################

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "default" {
  for_each = toset(data.aws_subnets.default.ids)

  id = each.value
}

locals {
  default_subnet_cidrs = [for k, v in data.aws_subnet.default : v.cidr_block]
}

################################################################################
# Get Current region
################################################################################

data "aws_region" "current" {}

################################################################################
# Get current AWS Account ID
################################################################################

data "aws_caller_identity" "current" {}
