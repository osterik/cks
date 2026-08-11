locals {
  region                 = "eu-north-1"
  backend_region         = "eu-north-1"
  backend_bucket         = "sre-learning-platform-state-backet"
  backend_dynamodb_table = "${local.backend_bucket}-lock"
}
