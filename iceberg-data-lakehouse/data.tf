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
# Get Route Tables
################################################################################

data "aws_route_tables" "default" {
  vpc_id = data.aws_vpc.default.id
}

################################################################################
# Get Current region
################################################################################

data "aws_region" "current" {}

################################################################################
# Get current AWS Account ID
################################################################################

data "aws_caller_identity" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

################################################################################
# Dependencies
################################################################################

resource "terraform_data" "dependencies" {
  depends_on = [
    aws_lakeformation_data_lake_settings.this,
    aws_lakeformation_permissions.database,
    aws_lakeformation_permissions.data_location,
    aws_lakeformation_permissions.table
  ]
}