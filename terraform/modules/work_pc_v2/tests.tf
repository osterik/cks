locals {
  # Handling case when tests passed as a local file, not HTTP URI

  tests_is_local  = startswith(var.work_pc.test_url, "file:")
  tests_file_path = local.tests_is_local ? trimprefix(var.work_pc.test_url, "file:") : ""
  tests_b64       = local.tests_is_local ? filebase64(local.tests_file_path) : ""

  # s3 path: "work-pc-tests/$USER_ID_$ENV_ID_$prefix/$app_name/$sha256.bats"
  tests_s3_key = "work-pc-tests/${local.prefix}/${var.app_name}/${sha256(local.tests_b64)}.bats"
  tests_s3_uri = "s3://${var.s3_k8s_config}/${local.tests_s3_key}"

  # Determine the method for transmitting tests (s3|user_data), taking into account that
  # the limit on user_data is 16KiB. 

  # First render the inline variant, but there is a problem with SSH password - 
  # the 'random_string.ssh.result' is unknown during the initial plan. Thus, render an
  # equivalent sizing variant with a fixed password of the same length so the
  # S3 resource count is known before apply. Keep a small gzip safety margin of 64b
  user_data_with_tests_inline_sizing_raw = templatefile("template/boot_zip.sh", {
    boot_zip = base64gzip(templatefile(var.work_pc.user_data_template, merge(local.user_data_template_vars, {
      ssh_password = substr("aB3dE5fG7h9J", 0, random_string.ssh.length)
      tests_b64    = local.tests_b64
      tests_s3_uri = ""
    })))
  })

  # if it less than 16Kib - let's send tests via user_data:
  use_inline_tests = (
    local.tests_is_local &&
    length(local.user_data_with_tests_inline_sizing_raw) <= 16 * 1024 - 64
  )

  # the final result: inline tests with generated SSH password
  user_data_inline_raw = templatefile("template/boot_zip.sh", {
    boot_zip = base64gzip(templatefile(var.work_pc.user_data_template, merge(local.user_data_template_vars, {
      tests_b64    = local.tests_b64
      tests_s3_uri = ""
    })))
  })

  # Option B: use S3
  upload_tests_s3 = local.tests_is_local && !local.use_inline_tests

  user_data_s3_raw = templatefile("template/boot_zip.sh", {
    boot_zip = base64gzip(templatefile(var.work_pc.user_data_template, merge(local.user_data_template_vars, {
      tests_b64    = ""
      tests_s3_uri = local.tests_s3_uri
    })))
  })

  # for debug purposed only, used only in "outputs"
  tests_delivery_method = (
    !local.tests_is_local ? "url" :
    local.use_inline_tests ? "user_data" : "s3"
  )
  # finally, use the selected option
  user_data_raw = local.upload_tests_s3 ? local.user_data_s3_raw : local.user_data_inline_raw

}
resource "aws_s3_object" "tests" {
  count = local.upload_tests_s3 ? 1 : 0

  provider       = aws.cmdb
  bucket         = var.s3_k8s_config
  key            = local.tests_s3_key
  content_base64 = local.tests_b64
  content_type   = "text/plain"
  tags           = local.tags_all
}
