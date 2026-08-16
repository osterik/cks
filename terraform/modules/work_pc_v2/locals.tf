locals {
  USER_ID            = var.USER_ID == "" ? "defaultUser" : var.USER_ID
  ENV_ID             = var.ENV_ID == "" ? "defaultId" : var.ENV_ID
  prefix_id          = "${local.USER_ID}_${local.ENV_ID}"
  prefix             = "${local.prefix_id}_${var.prefix}"
  item_id_lock       = "CMDB_lock_${local.USER_ID}_${local.ENV_ID}_${var.app_name}_${var.prefix}"
  item_id_data       = "CMDB_data_${local.USER_ID}_${local.ENV_ID}_${var.app_name}_${var.prefix}"
  subnets            = var.subnets
  all_instance_types = toset(var.spot_additional_types)
  ssh_password_len   = 10

  type_sub_spot = {
    for pair in setproduct(local.all_instance_types, var.subnets) :
    "${pair[0]}-${pair[1]}" => {
      type   = pair[0]
      subnet = pair[1]
    }
  }
  worker_pc_ssh = var.ssh_password_enable == "true" ? "   ssh ubuntu@${local.worker_pc_ip} password= ${random_string.ssh.result}   " : "   ssh ubuntu@${local.worker_pc_ip}   "
  tags_app = {
    "Name"     = "${local.prefix}-${var.app_name}"
    "app_name" = var.app_name
  }
  tags_all = merge(var.tags_common, local.tags_app)
  tags_k8_master = {
    "k8_node_type" = "worker-pc"
    "Name"         = "${local.prefix}-${var.app_name}-worker-pc"
  }
  tags_all_k8_master = var.work_pc.node_type == "spot" ? merge(local.tags_all, local.tags_k8_master) : {}

  worker_pc_ip       = var.work_pc.node_type == "spot" ? join("", data.aws_instances.spot_fleet["enable"].public_ips) : aws_instance.master["enable"].public_ip
  worker_pc_ip_local = var.work_pc.node_type == "spot" ? join("", data.aws_instances.spot_fleet["enable"].private_ips) : aws_instance.master["enable"].private_ip
  master_ami         = var.work_pc.ami_id != "" ? var.work_pc.ami_id : data.aws_ami.master.image_id
  worker_pc_id       = var.work_pc.node_type == "spot" ? join("", data.aws_instances.spot_fleet["enable"].ids) : aws_instance.master["enable"].id
  hosts              = join(" ", var.host_list)

  user_data_template_vars = {
    clusters_config     = join(" ", [for key, value in var.work_pc.clusters_config : "${key}=${value}"])
    kubectl_version     = var.work_pc.util.kubectl_version
    ssh_private_key     = var.work_pc.ssh.private_key
    ssh_pub_key         = var.work_pc.ssh.pub_key
    exam_time_minutes   = var.work_pc.exam_time_minutes
    test_url            = local.tests_is_local ? "" : var.work_pc.test_url
    task_script_url     = local.task_script_is_local ? "" : var.work_pc.task_script_url
    task_script_b64     = local.task_script_b64
    ssh_password        = random_string.ssh.result
    ssh_password_enable = var.ssh_password_enable
    hosts               = local.hosts
    hostname            = var.app_name
  }

  # inject task script from local filesystem
  task_script_is_local  = startswith(var.work_pc.task_script_url, "file:")
  task_script_file_path = local.task_script_is_local ? trimprefix(var.work_pc.task_script_url, "file:") : ""
  task_script_b64       = local.task_script_is_local ? filebase64(local.task_script_file_path) : ""
}
