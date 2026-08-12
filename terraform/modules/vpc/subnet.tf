data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "subnets_pub" {
  for_each = var.az_ids

  vpc_id                  = aws_vpc.default.id
  map_public_ip_on_launch = true
  cidr_block              = each.key
  availability_zone_id = can(tonumber(each.value)) ? (
    data.aws_availability_zones.available.zone_ids[tonumber(each.value)]
  ) : each.value

  tags = local.tags_all

  depends_on = [aws_dynamodb_table_item.cmdb]

  lifecycle {
    ignore_changes = [
      tags,
      tags_all
    ]
  }
}
