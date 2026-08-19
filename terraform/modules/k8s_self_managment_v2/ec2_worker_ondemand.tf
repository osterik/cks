resource "aws_instance" "worker" {
  for_each                    = local.k8s_worker_ondemand
  iam_instance_profile        = aws_iam_instance_profile.server.id
  associate_public_ip_address = "true"
  ami                         = each.value.ami_id != "" ? each.value.ami_id : data.aws_ami.worker["${each.key}"].image_id
  instance_type               = each.value.instance_type
  subnet_id                   = local.subnets[each.value.subnet_number]
  key_name                    = each.value.key_name != "" ? each.value.key_name : null
  security_groups             = [aws_security_group.servers.id]
  lifecycle {
    ignore_changes = [
      instance_type,
      user_data_base64,
      root_block_device,
      key_name,
      security_groups
    ]
  }

  user_data_base64 = base64encode(local.worker_user_data_raw[each.key])
  depends_on       = [aws_s3_object.worker_task_script]


  tags = local.tags_all
  root_block_device {
    volume_size           = each.value.root_volume.size
    volume_type           = each.value.root_volume.type
    delete_on_termination = true
    tags                  = local.tags_all
    encrypted             = true
  }

}
