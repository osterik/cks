resource "aws_s3_bucket" "backend" {
  region = var.backend_region
  bucket = var.backend_bucket
}

resource "aws_s3_bucket_versioning" "backend" {
  region = var.backend_region
  bucket = aws_s3_bucket.backend.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backend" {
  region = var.backend_region
  bucket = aws_s3_bucket.backend.id

  rule {
    blocked_encryption_types = ["SSE-C"]
    bucket_key_enabled       = false

    apply_server_side_encryption_by_default {
      kms_master_key_id = "arn:aws:kms:${var.backend_region}:${data.aws_caller_identity.current.account_id}:alias/aws/s3"
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backend" {
  region = var.backend_region
  bucket = aws_s3_bucket.backend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "backend" {
  region = var.backend_region
  bucket = aws_s3_bucket.backend.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# 1. Remove old noncurrent versions and delete markers in 1d
# 2. Clean config/ after 1d
resource "aws_s3_bucket_lifecycle_configuration" "backend" {
  region = var.backend_region
  bucket = aws_s3_bucket.backend.id

  depends_on = [aws_s3_bucket_versioning.backend]

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    filter {}

    expiration {
      expired_object_delete_marker = true
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }

  rule {
    id     = "delete-config-objects"
    status = "Enabled"

    filter {
      prefix = "config/"
    }

    expiration {
      days = 1
    }
  }
}

data "aws_iam_policy_document" "backend_bucket_policy" {
  statement {
    sid     = "EnforcedTLS"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.backend.arn,
      "${aws_s3_bucket.backend.arn}/*"
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid     = "RootAccess"
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.backend.arn,
      "${aws_s3_bucket.backend.arn}/*"
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_s3_bucket_policy" "backend" {
  region = var.backend_region
  bucket = aws_s3_bucket.backend.id
  policy = data.aws_iam_policy_document.backend_bucket_policy.json
}
