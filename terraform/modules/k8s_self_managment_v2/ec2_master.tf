resource "aws_iam_role" "fleet_role" {
  for_each = toset(var.node_type == "spot" ? ["enable"] : [])
  name     = "${local.prefix}-${var.app_name}-${var.cluster_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "spotfleet.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "fleet_role" {
  for_each = toset(var.node_type == "spot" ? ["enable"] : [])
  name     = "${local.prefix}-${var.app_name}-${var.cluster_name}"
  policy   = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeImages",
                "ec2:DescribeSubnets",
                "ec2:RequestSpotInstances",
                "ec2:TerminateInstances",
                "ec2:DescribeInstanceStatus",
                "ec2:CreateTags",
                "ec2:RunInstances"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": [
                        "ec2.amazonaws.com",
                        "ec2.amazonaws.com.cn"
                    ]
                }
            },
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:RegisterInstancesWithLoadBalancer"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:RegisterTargets"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:*/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy_attachment" "fleet_role" {
  for_each   = toset(var.node_type == "spot" ? ["enable"] : [])
  name       = "${local.prefix}-${var.app_name}-${var.cluster_name}"
  policy_arn = aws_iam_policy.fleet_role["enable"].arn
  roles      = [aws_iam_role.fleet_role["enable"].name]
}


resource "aws_launch_template" "master" {
  for_each      = toset(var.node_type == "spot" ? ["enable"] : [])
  name_prefix   = "${local.prefix}-${var.app_name}"
  image_id      = local.master_ami
  instance_type = var.k8s_master.instance_type
  user_data     = base64encode(local.master_user_data_raw)
  depends_on    = [aws_s3_object.master_task_script]
  key_name      = var.k8s_master.key_name != "" ? var.k8s_master.key_name : null
  tags          = local.tags_all_k8_master

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.servers.id]
    delete_on_termination       = "true"
    subnet_id                   = local.subnets[var.k8s_master.subnet_number]
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      delete_on_termination = "true"
      volume_size           = var.k8s_master.root_volume.size
      volume_type           = var.k8s_master.root_volume.type
      encrypted             = true

    }

  }
  tag_specifications {
    resource_type = "instance"
    tags          = local.tags_all_k8_master
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.tags_all_k8_master
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.server.name
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_spot_fleet_request" "master" {
  for_each                      = toset(var.node_type == "spot" ? ["enable"] : [])
  iam_fleet_role                = aws_iam_role.fleet_role["enable"].arn
  target_capacity               = 1
  wait_for_fulfillment          = true
  terminate_instances_on_delete = true
  tags                          = { type = "master", env = var.cluster_name, app = var.app_name, key = each.key }
  launch_template_config {
    launch_template_specification {
      id      = aws_launch_template.master["enable"].id
      version = aws_launch_template.master["enable"].latest_version
    }
    dynamic "overrides" {
      for_each = var.all_spot_subnet == "true" ? local.type_sub_spot : {}
      content {
        instance_type = overrides.value.type
        subnet_id     = overrides.value.subnet
      }
    }
  }
}


data "aws_instances" "spot_fleet_master" {
  for_each = toset(var.node_type == "spot" ? ["enable"] : [])
  instance_tags = {
    "aws:ec2spot:fleet-request-id" = aws_spot_fleet_request.master["enable"].id
  }
}
