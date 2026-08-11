# 0-bootstrap

Creates a restricted AWS IAM policy for the lab environment. It grants regional access to EC2, VPC, and EKS, global IAM access, and full access to the configured S3 bucket and DynamoDB table.

1. Create `terraform.tfvars` file and fill it
``` hcl
aws_region          = "eu-west-1"
s3_bucket_name      = "osterik-cka-mock-bucket-eu-west-1"
dynamodb_table_name = "osterik-cka-mock-bucket-eu-west-1-lock"
```

2. `terraform apply`

3. Use the `policy_arn` from output for account that will deploy CKA labs
