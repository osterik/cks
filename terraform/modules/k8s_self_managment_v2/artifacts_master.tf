locals {
  # file: is resolved on the Terraform runner and embedded as Base64 when it
  # fits. HTTPS values remain URLs and continue to be downloaded with curl.
  master_task_script_is_local  = startswith(var.k8s_master.task_script_url, "file:")
  master_task_script_file_path = local.master_task_script_is_local ? trimprefix(var.k8s_master.task_script_url, "file:") : ""
  master_task_script_b64       = local.master_task_script_is_local ? filebase64(local.master_task_script_file_path) : ""

  # Content-addressed names ensure that modifying a script creates a new object
  # instead of allowing an instance to retrieve stale content.
  master_task_script_s3_key = "k8s-artifacts/${local.prefix}/${var.cluster_name}/master-task-${sha256(local.master_task_script_b64)}.sh"
  master_task_script_s3_uri = "s3://${var.s3_k8s_config}/${local.master_task_script_s3_key}"

  # Common variables used by both the sizing and final master renders.
  master_user_data_vars = {
    worker_join             = local.worker_join
    k8s_config              = local.k8s_config
    external_ip             = local.external_ip
    k8_version              = var.k8s_master.k8_version
    k8_version_sh           = var.k8s_master.k8_version
    runtime                 = var.k8s_master.runtime
    utils_enable            = var.k8s_master.utils_enable
    pod_network_cidr        = var.k8s_master.pod_network_cidr
    runtime_script          = file(var.k8s_master.runtime_script)
    task_script_url         = local.master_task_script_is_local ? "" : var.k8s_master.task_script_url
    cni_type                = var.k8s_master.cni.type
    calico_url              = var.k8s_master.cni.calico_url
    cilium_version          = var.k8s_master.cni.cilium_version
    cilium_helm_version     = var.k8s_master.cni.cilium_helm_version
    disable_kube_proxy      = var.k8s_master.cni.disable_kube_proxy
    ssh_private_key         = var.k8s_master.ssh.private_key
    ssh_pub_key             = var.k8s_master.ssh.pub_key
    ssh_password            = random_string.ssh.result
    ssh_password_enable     = var.ssh_password_enable
    kubeadm_init_extra_args = var.k8s_master.kubeadm_init_extra_args
  }

  # Resource-derived values are unknown during the initial plan. Replace them
  # with representative values so the S3 resource count is plan-time-known.
  master_user_data_inline_sizing_raw = templatefile("template/boot_zip.sh", {
    boot_zip = base64gzip(templatefile(var.k8s_master.user_data_template, merge(local.master_user_data_vars, {
      worker_join        = "sizing/config/worker_join"
      k8s_config         = "sizing/config/config"
      external_ip        = "255.255.255.255"
      ssh_password       = substr("aB3dE5fG7h9J", 0, random_string.ssh.length)
      task_script_b64    = local.master_task_script_b64
      task_script_s3_uri = ""
    })))
  })

  # Use S3 only when the complete master bootstrap no longer fits inline.
  master_upload_task_script_s3 = (
    local.master_task_script_is_local &&
    length(local.master_user_data_inline_sizing_raw) > local.user_data_limit_bytes - local.user_data_safety_bytes
  )

  # Final master render: include either the script body or its S3 URI.
  master_user_data_raw = templatefile("template/boot_zip.sh", {
    boot_zip = base64gzip(templatefile(var.k8s_master.user_data_template, merge(local.master_user_data_vars, {
      task_script_b64    = local.master_upload_task_script_s3 ? "" : local.master_task_script_b64
      task_script_s3_uri = local.master_upload_task_script_s3 ? local.master_task_script_s3_uri : ""
    })))
  })
}

# The EC2 master depends on this object, preventing cloud-init from racing the upload.
resource "aws_s3_object" "master_task_script" {
  count = local.master_upload_task_script_s3 ? 1 : 0

  provider       = aws.cmdb
  bucket         = var.s3_k8s_config
  key            = local.master_task_script_s3_key
  content_base64 = local.master_task_script_b64
  content_type   = "text/x-shellscript"
  tags           = local.tags_all
}
