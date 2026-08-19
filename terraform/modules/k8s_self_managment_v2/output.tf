output "master_external_ip" {
  value = local.master_ip_public
}

output "cluster" {
  value = var.cluster_name
}
output "master_local_ip" {
  value = local.master_local_ip
}
output "node_type" {
  value = var.node_type
}
output "worker_join" {
  value = "s3://${local.worker_join}"
}

output "k8s_config" {
  value = "s3://${local.k8s_config}"
}
output "k8_master_version" {
  value = var.k8s_master.k8_version
}

output "master_ssh" {
  value = "ssh ubuntu@${local.master_ip_public}  password= ${random_string.ssh.result}  "
}

output "eip" {
  value = var.k8s_master.eip
}

output "check_node_status" {
  value = "tail -f /var/log/cloud-init-output.log "
}

output "s3_k8s_config" {
  value = local.k8s_config
}

output "worker_nodes" {
  value = local.worker_nodes
}

output "ami_id_master" {
  value = local.master_ami
}

output "master_instance_type" {
  value = local.master_instance_type
}

output "worker_reload_bashrc" {
  value = "  source ~/.bashrc   "
}
output "ec2_key" {
  value = var.k8s_master.key_name
}

output "ssh_password" {
  value = "  ${random_string.ssh.result}   "
}

output "hosts_worker_node" {
  value = local.hosts_worker_node
}
output "hosts_master_node" {
  value = local.hosts_master_node
}

output "hosts" {
  value = local.hosts
}

output "ssh_password_enable" {
  value = var.ssh_password_enable
}

output "master" {
  value = var.k8s_master
}

output "master_user_data_size_bytes" {
  description = "Raw master EC2 user_data size before Base64 encoding"
  value       = length(local.master_user_data_raw)

  precondition {
    condition     = length(local.master_user_data_raw) <= local.user_data_limit_bytes
    error_message = "Master EC2 user_data exceeds the 16384-byte limit after artifact selection."
  }
}

output "master_task_script_delivery_method" {
  description = "Selected master task script delivery method: user_data, s3, or url"
  value = (
    !local.master_task_script_is_local ? "url" :
    local.master_upload_task_script_s3 ? "s3" : "user_data"
  )
}

output "worker_user_data_size_bytes" {
  description = "Raw worker EC2 user_data sizes before Base64 encoding"
  value       = { for key, data in local.worker_user_data_raw : key => length(data) }

  precondition {
    condition = alltrue([
      for data in values(local.worker_user_data_raw) : length(data) <= local.user_data_limit_bytes
    ])
    error_message = "At least one worker EC2 user_data value exceeds the 16384-byte limit after artifact selection."
  }
}

output "worker_task_script_delivery_method" {
  description = "Selected worker task script delivery methods"
  value = {
    for key, is_local in local.worker_task_script_is_local : key => (
      !is_local ? "url" : local.worker_upload_task_script_s3[key] ? "s3" : "user_data"
    )
  }
}
