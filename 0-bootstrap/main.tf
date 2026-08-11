variable "aws_region" {
  description = "The region where the resources are located"
  type        = string
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
}

variable "dynamodb_table_name" {
  description = "The name of the DynamoDB table"
  type        = string
}


data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "admin_restricted_policy" {
  # 1. Regional Admin for EC2/VPC and EKS
  statement {
    sid    = "RegionalAdminPrivileges"
    effect = "Allow"
    actions = [
      "ec2:*",
      "eks:*"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  # 2. Global Admin for IAM (IAM does not support regional conditions)
  statement {
    sid    = "IAMAdminPrivilegesGlobal"
    effect = "Allow"
    actions = [
      "iam:*"
    ]
    resources = ["*"]
  }

  # 3. Full access to specific S3 Bucket
  statement {
    sid     = "S3FullAccessToSpecificBucket"
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${var.s3_bucket_name}",
      "arn:aws:s3:::${var.s3_bucket_name}/*"
    ]
  }

  # 4. Full access to specific DynamoDB Table
  statement {
    sid     = "DynamoDBFullAccessToSpecificTable"
    effect  = "Allow"
    actions = ["dynamodb:*"]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table_name}",
      "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table_name}/index/*"
    ]
  }
}

resource "aws_iam_policy" "custom_admin_policy" {
  name        = "CKAMockRegionalAdminPolicy"
  path        = "/"
  description = "Admin access for VPC, EC2, IAM, EKS in ${var.aws_region} and specific S3/DDB resources"
  policy      = data.aws_iam_policy_document.admin_restricted_policy.json
}


output "policy_arn" {
  value = aws_iam_policy.custom_admin_policy.arn
}
