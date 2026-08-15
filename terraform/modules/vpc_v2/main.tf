
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # auto assign AZ if weren't assigned explicitly
  available_azs       = sort(data.aws_availability_zones.available.names)
  public_subnet_keys  = sort(keys(var.subnets.public))
  private_subnet_keys = sort(keys(var.subnets.private))

  normalized_subnets = {
    public = {
      for subnet_key, subnet in var.subnets.public : subnet_key => merge(subnet, {
        az = coalesce(subnet.az, local.available_azs[index(local.public_subnet_keys, subnet_key) % length(local.available_azs)])
      })
    }
    private = {
      for subnet_key, subnet in var.subnets.private : subnet_key => merge(subnet, {
        az = coalesce(subnet.az, local.available_azs[index(local.private_subnet_keys, subnet_key) % length(local.available_azs)])
      })
    }
  }
}

module "vpc" {
  depends_on   = [aws_dynamodb_table_item.cmdb]
  source       = "ViktorUJ/vpc/aws"
  version      = "1.1.0"
  tags_default = var.tags_common
  vpc = {
    name = "${var.prefix}-${var.USER_ID}-${var.ENV_ID}-${var.STACK_NAME}-${var.STACK_TASK}"
    cidr = var.vpc_default_cidr
  }

  subnets = local.normalized_subnets
}
