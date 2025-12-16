# Terraform folders

Folders created:

- `terraform/runner` — Terraform to launch a t3.micro EC2 instance (basic SG + outputs).
- `terraform/github-secrets` — Terraform to create GitHub Actions repository secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`.

Notes:

- Set credentials via environment variables or `terraform.tfvars` when running locally. For the GitHub secrets module you must provide a `github_token` with sufficient scope and `github_owner` + `repository` where the secrets will be stored.
- The GitHub Actions workflow reads AWS credentials from repository secrets named `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN`.
- The lab module `terraform/lab` creates two VPCs in Oregon (`us-west-2`) and peering between them. The `server` VPC contains an EKS cluster (small nodes) with a simple "hello world" deployment and the Tailscale Operator. The `client` VPC contains an Ubuntu VM (t3.small) with the Tailscale client installed and configured to use `TF_VAR_tailscale_auth_key`.

- The `terraform/lab` module details:
	- Builds two VPCs (`server` and `client`) and peering between them.
	- Creates an EKS cluster in the `server` VPC and deploys a small `hello` app plus the Tailscale Operator via Helm.
	- Creates an Ubuntu VM in a private subnet of the `client` VPC that connects to the internet via a NAT gateway and runs the Tailscale client.
	- Provides an optional Tailscale subnet-router instance in the `client` public subnet (toggle with `TF_VAR_tailscale_subnet_router_enable`). When enabled the router will advertise the `client` VPC private subnets to Tailscale using `TF_VAR_tailscale_auth_key`.

Notes and caveats:

	- The EKS module used depends on community modules (`terraform-aws-modules/eks/aws`) and the VPC module (`terraform-aws-modules/vpc/aws`). Run `terraform init` to fetch them.
	- Tailscale auth keys are sensitive: set `TF_VAR_tailscale_auth_key` in environment or a secure `terraform.tfvars` file.
	- This lab is intentionally permissive and directed at experimentation — review IAM and security-group settings before using in production.
- The runner EC2 is created with an IAM instance profile that grants broad `ec2:*` permissions (VPC + EC2 admin). This is overly permissive and intended only for lab or disposable environments — do not use this IAM configuration in production.

Quick local example (runner):

```bash
cd terraform/runner
terraform init
terraform plan
terraform apply
```

Quick local example (github-secrets):

```bash
cd terraform/github-secrets
export TF_VAR_github_token="ghp_..."
export TF_VAR_github_owner="my-org"
export TF_VAR_repository="my-repo"
export TF_VAR_aws_access_key_id="..."
export TF_VAR_aws_secret_access_key="..."
export TF_VAR_aws_session_token="..." # optional
terraform init
terraform apply
```
