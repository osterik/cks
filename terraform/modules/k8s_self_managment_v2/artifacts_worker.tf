locals {
  # Every worker is sized independently because worker entries may use
  # different task scripts and user_data templates.
  # file: values are read on the Terraform runner. HTTPS values retain the
  # existing curl-based delivery path.
  worker_task_script_is_local = {
    for key, worker in var.k8s_worker : key => startswith(worker.task_script_url, "file:")
  }
  worker_task_script_b64 = {
    for key, worker in var.k8s_worker : key => (
      local.worker_task_script_is_local[key] ? filebase64(trimprefix(worker.task_script_url, "file:")) : ""
    )
  }

  # Content-addressed keys prevent stale scripts from being reused.
  worker_task_script_s3_key = {
    for key, content in local.worker_task_script_b64 :
    key => "k8s-artifacts/${local.prefix}/${var.cluster_name}/${key}-task-${sha256(content)}.sh"
  }
  worker_task_script_s3_uri = {
    for key, object_key in local.worker_task_script_s3_key : key => "s3://${var.s3_k8s_config}/${object_key}"
  }

  # Common values used by sizing and final renders for every worker.
  worker_user_data_vars = {
    for key, worker in var.k8s_worker : key => {
      worker_join         = local.worker_join
      k8s_config          = local.k8s_config
      k8_version          = worker.k8_version
      runtime             = worker.runtime
      runtime_script      = file(worker.runtime_script)
      task_script_url     = local.worker_task_script_is_local[key] ? "" : worker.task_script_url
      node_name           = key
      node_labels         = worker.node_labels
      ssh_private_key     = worker.ssh.private_key
      ssh_pub_key         = worker.ssh.pub_key
      ssh_password        = random_string.ssh.result
      ssh_password_enable = var.ssh_password_enable
    }
  }

  # Replace apply-time values with representative values so for_each is known
  # during planning. The safety reserve covers small gzip-size differences.
  worker_user_data_inline_sizing_raw = {
    for key, worker in var.k8s_worker : key => templatefile("template/boot_zip.sh", {
      boot_zip = base64gzip(templatefile(worker.user_data_template, merge(local.worker_user_data_vars[key], {
        worker_join        = "sizing/config/worker_join"
        k8s_config         = "sizing/config/config"
        ssh_password       = substr("aB3dE5fG7h9J", 0, random_string.ssh.length)
        task_script_b64    = local.worker_task_script_b64[key]
        task_script_s3_uri = ""
      })))
    })
  }

  # Select inline or S3 separately for every worker.
  worker_upload_task_script_s3 = {
    for key, worker in var.k8s_worker : key => (
      local.worker_task_script_is_local[key] &&
      length(local.worker_user_data_inline_sizing_raw[key]) > local.user_data_limit_bytes - local.user_data_safety_bytes
    )
  }

  # Final worker renders use the real values and selected delivery method.
  worker_user_data_raw = {
    for key, worker in var.k8s_worker : key => templatefile("template/boot_zip.sh", {
      boot_zip = base64gzip(templatefile(worker.user_data_template, merge(local.worker_user_data_vars[key], {
        task_script_b64    = local.worker_upload_task_script_s3[key] ? "" : local.worker_task_script_b64[key]
        task_script_s3_uri = local.worker_upload_task_script_s3[key] ? local.worker_task_script_s3_uri[key] : ""
      })))
    })
  }
}

# Worker instances depend on these objects before starting cloud-init.
resource "aws_s3_object" "worker_task_script" {
  for_each = {
    for key, upload in local.worker_upload_task_script_s3 : key => upload if upload
  }

  provider       = aws.cmdb
  bucket         = var.s3_k8s_config
  key            = local.worker_task_script_s3_key[each.key]
  content_base64 = local.worker_task_script_b64[each.key]
  content_type   = "text/x-shellscript"
  tags           = local.tags_all
}
