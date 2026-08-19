locals {
  # EC2 limits raw user_data to 16 KiB before the outer Base64 encoding.
  # Keep a small reserve because the sizing render uses a deterministic
  # placeholder instead of the password generated during apply.
  user_data_limit_bytes  = 16 * 1024
  user_data_safety_bytes = 64

  # A value beginning with file: points to a file on the Terraform runner.
  # HTTPS values are left in user_data_template_vars and retain the old curl path.
  tests_is_local  = startswith(var.work_pc.test_url, "file:")
  tests_file_path = local.tests_is_local ? trimprefix(var.work_pc.test_url, "file:") : ""
  tests_b64       = local.tests_is_local ? filebase64(local.tests_file_path) : ""
  # The content hash makes object names immutable and prevents stale files from
  # being reused after a local artifact changes.
  tests_s3_key = "work-pc-artifacts/${local.prefix}/${var.app_name}/tests-${sha256(local.tests_b64)}.bats"
  tests_s3_uri = "s3://${var.s3_k8s_config}/${local.tests_s3_key}"

  task_script_is_local  = startswith(var.work_pc.task_script_url, "file:")
  task_script_file_path = local.task_script_is_local ? trimprefix(var.work_pc.task_script_url, "file:") : ""
  task_script_b64       = local.task_script_is_local ? filebase64(local.task_script_file_path) : ""
  task_script_s3_key    = "work-pc-artifacts/${local.prefix}/${var.app_name}/task-${sha256(local.task_script_b64)}.sh"
  task_script_s3_uri    = "s3://${var.s3_k8s_config}/${local.task_script_s3_key}"

  # random_string.ssh.result is unknown during the initial plan. The selector
  # must be plan-time-known because it controls aws_s3_object count, so sizing
  # uses a fixed password with exactly the same configured length.
  artifact_sizing_vars = merge(local.user_data_template_vars, {
    ssh_password = substr("aB3dE5fG7h9J", 0, random_string.ssh.length)
  })

  # Candidate A: keep both local artifacts inside compressed user_data.
  user_data_both_inline_sizing_raw = templatefile("template/boot_zip.sh", {
    boot_zip = base64gzip(templatefile(var.work_pc.user_data_template, merge(local.artifact_sizing_vars, {
      tests_b64          = local.tests_b64
      tests_s3_uri       = ""
      task_script_b64    = local.task_script_b64
      task_script_s3_uri = ""
    })))
  })

  # Candidate B: put tests in S3 and keep the task script inline.
  user_data_tests_s3_sizing_raw = templatefile("template/boot_zip.sh", {
    boot_zip = base64gzip(templatefile(var.work_pc.user_data_template, merge(local.artifact_sizing_vars, {
      tests_b64          = ""
      tests_s3_uri       = local.tests_is_local ? local.tests_s3_uri : ""
      task_script_b64    = local.task_script_b64
      task_script_s3_uri = ""
    })))
  })

  # Candidate C: keep tests inline and put the task script in S3.
  user_data_task_s3_sizing_raw = templatefile("template/boot_zip.sh", {
    boot_zip = base64gzip(templatefile(var.work_pc.user_data_template, merge(local.artifact_sizing_vars, {
      tests_b64          = local.tests_b64
      tests_s3_uri       = ""
      task_script_b64    = ""
      task_script_s3_uri = local.task_script_is_local ? local.task_script_s3_uri : ""
    })))
  })

  inline_limit    = local.user_data_limit_bytes - local.user_data_safety_bytes
  both_inline_fit = length(local.user_data_both_inline_sizing_raw) <= local.inline_limit
  tests_s3_fit    = local.tests_is_local && length(local.user_data_tests_s3_sizing_raw) <= local.inline_limit
  task_s3_fit     = local.task_script_is_local && length(local.user_data_task_s3_sizing_raw) <= local.inline_limit

  # Prefer a single S3 object. If either one-file fallback fits, select the
  # candidate producing the smaller user_data. If neither fits, upload both.
  prefer_tests_s3 = local.tests_s3_fit && (!local.task_s3_fit || length(local.user_data_tests_s3_sizing_raw) <= length(local.user_data_task_s3_sizing_raw))
  prefer_task_s3  = local.task_s3_fit && (!local.tests_s3_fit || length(local.user_data_task_s3_sizing_raw) < length(local.user_data_tests_s3_sizing_raw))
  require_both_s3 = !local.both_inline_fit && !local.tests_s3_fit && !local.task_s3_fit

  upload_tests_s3       = !local.both_inline_fit && local.tests_is_local && (local.prefer_tests_s3 || local.require_both_s3)
  upload_task_script_s3 = !local.both_inline_fit && local.task_script_is_local && (local.prefer_task_s3 || local.require_both_s3)

  # Render the real bootstrap with the generated password and the delivery
  # variables selected above. Templates decode Base64, copy from S3, or curl.
  user_data_raw = templatefile("template/boot_zip.sh", {
    boot_zip = base64gzip(templatefile(var.work_pc.user_data_template, merge(local.user_data_template_vars, {
      tests_b64          = local.upload_tests_s3 ? "" : local.tests_b64
      tests_s3_uri       = local.upload_tests_s3 ? local.tests_s3_uri : ""
      task_script_b64    = local.upload_task_script_s3 ? "" : local.task_script_b64
      task_script_s3_uri = local.upload_task_script_s3 ? local.task_script_s3_uri : ""
    })))
  })

  tests_delivery_method       = !local.tests_is_local ? "url" : local.upload_tests_s3 ? "s3" : "user_data"
  task_script_delivery_method = !local.task_script_is_local ? "url" : local.upload_task_script_s3 ? "s3" : "user_data"
}

# Objects are created only for artifacts selected for S3. Instance resources
# explicitly depend on both objects, preventing cloud-init from racing uploads.
resource "aws_s3_object" "tests" {
  count = local.upload_tests_s3 ? 1 : 0

  provider       = aws.cmdb
  bucket         = var.s3_k8s_config
  key            = local.tests_s3_key
  content_base64 = local.tests_b64
  content_type   = "text/plain"
  tags           = local.tags_all
}

resource "aws_s3_object" "task_script" {
  count = local.upload_task_script_s3 ? 1 : 0

  provider       = aws.cmdb
  bucket         = var.s3_k8s_config
  key            = local.task_script_s3_key
  content_base64 = local.task_script_b64
  content_type   = "text/x-shellscript"
  tags           = local.tags_all
}
