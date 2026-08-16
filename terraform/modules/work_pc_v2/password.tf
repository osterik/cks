resource "random_string" "ssh" {
  length  = local.ssh_password_len # TODO: check if it could be repalced with random_string.ssh.length
  special = false
}
