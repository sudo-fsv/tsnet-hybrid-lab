variable "aws_region" {
  description = "AWS region to create the lab in (Oregon)"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "lab-eks-cluster"
}

variable "node_instance_type" {
  description = "Instance type for EKS worker nodes"
  type        = string
  default     = "t3.small"
}

variable "client_instance_type" {
  description = "Instance type for Ubuntu client VM"
  type        = string
  default     = "t3.small"
}

variable "tailscale_auth_key" {
  description = "Tailscale auth key (use a reusable key or ephemeral key)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tailscale_subnet_router_enable" {
  description = "If true, create a subnet router instance in the public subnet that advertises routes"
  type        = bool
  default     = true
}

variable "enable_ssh_access" {
  description = "Allow SSH from 0.0.0.0/0 to instances (for lab only)"
  type        = bool
  default     = false
}

variable "tailscale_oauth_client_id" {
  description = "OAuth client ID for Tailscale (used by the operator)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tailscale_oauth_client_secret" {
  description = "OAuth client secret for Tailscale (used by the operator)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tailscale_api_key" {
  description = "API key for the Tailscale Terraform provider (set via TF_VAR_tailscale_api_key or env var)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tsnet_domain" {
  description = "Tailscale network domain to append to device hostnames (e.g. taild1234d.ts.net)"
  type        = string
  default     = ""
}

variable "tailscale_cleanup_target_names" {
  description = "List of tag names or name substrings to match against Tailscale device tags/names for cleanup during destroy. If empty, cleanup is skipped."
  type        = list(string)
  sensitive   = false
  default     = ["tailscale","aws-linux-vm"]
}
