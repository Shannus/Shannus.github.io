# Remote state in S3 with native lockfile-based locking (no DynamoDB table needed).
# Create the bucket in the runbook bootstrap step, then fill it in and `terraform init -migrate-state`.
# For a first local run you can comment this whole block out to use local state.
terraform {
  backend "s3" {
    bucket       = "REPLACE-with-your-tfstate-bucket"
    key          = "portfolio/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
