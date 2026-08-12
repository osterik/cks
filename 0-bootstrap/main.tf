variable "region" {
  description = "The AWS region where EC2, VPC, and EKS resources are deployed"
  type        = string
}

variable "backend_region" {
  description = "The AWS region containing the S3 backend bucket and CMDB DynamoDB table"
  type        = string
}

variable "backend_bucket" {
  description = "The name of the S3 bucket used for Terraform state and S3 lock files"
  type        = string
}

variable "cmdb_dynamodb_table" {
  description = "The name of the DynamoDB table used by the CMDB"
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
      values   = [var.region]
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
      "arn:aws:s3:::${var.backend_bucket}",
      "arn:aws:s3:::${var.backend_bucket}/*"
    ]
  }

  # 4. Full access to specific DynamoDB Table
  statement {
    sid     = "DynamoDBFullAccessToSpecificTable"
    effect  = "Allow"
    actions = ["dynamodb:*"]
    resources = [
      "arn:aws:dynamodb:${var.backend_region}:${data.aws_caller_identity.current.account_id}:table/${var.cmdb_dynamodb_table}",
      "arn:aws:dynamodb:${var.backend_region}:${data.aws_caller_identity.current.account_id}:table/${var.cmdb_dynamodb_table}/index/*"
    ]
  }
}

resource "aws_iam_policy" "custom_admin_policy" {
  name        = "CKAMockRegionalAdminPolicy"
  path        = "/"
  description = "Admin access for VPC, EC2, IAM, EKS in ${var.region} and specific S3/DDB resources"
  # description = "Admin access for VPC, EC2, and EKS in ${var.region}, IAM globally, and backend resources in ${var.backend_region}"  
  policy      = data.aws_iam_policy_document.admin_restricted_policy.json
}


output "policy_arn" {
  value = aws_iam_policy.custom_admin_policy.arn
}
