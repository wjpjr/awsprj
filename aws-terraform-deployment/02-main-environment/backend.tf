# Remote state with locking. Create the S3 bucket + DynamoDB table once,
# beforehand (e.g. via a separate bootstrap config), then uncomment this block.

terraform {
  backend "s3" {
    bucket         = "my-org-terraform-state-v1"
    key            = "envs/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
