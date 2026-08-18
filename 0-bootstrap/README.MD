# 0-bootstrap

Creates a restricted AWS IAM policy for the lab environment. It grants access to EC2, VPC, and EKS in the deployment region, global IAM access, and access to the S3 backend bucket and CMDB DynamoDB table in the backend region. Terraform state locking is stored in S3.

1. Create `terraform.tfvars` file and fill it
``` hcl
region              = "eu-central-1"
backend_region      = "eu-west-1"
backend_bucket      = "<uniq_prefix>-cka-mock-bucket-eu-west-1"
cmdb_dynamodb_table = "cka-mock-cmdb"
```

2. `terraform apply`

3. Use the `policy_arn` from output for account that will deploy CKA labs
