terraform {
  backend "s3" {}
}

# This backend block is intentionally empty so GitHub Actions can supply
# backend configuration at init time using `-backend-config` flags.
# Example (workflow):
# terraform init -backend-config=bucket=your-bucket -backend-config=key=lab/terraform.tfstate \
#   -backend-config=region=us-west-2 -backend-config=encrypt=true
