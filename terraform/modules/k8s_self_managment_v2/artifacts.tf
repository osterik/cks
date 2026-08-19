locals {
  # EC2 limits raw user_data to 16 KiB before outer Base64 encoding. Keep a
  # reserve because plan-time sizing substitutes generated resource values.
  user_data_limit_bytes  = 16 * 1024
  user_data_safety_bytes = 256
}
