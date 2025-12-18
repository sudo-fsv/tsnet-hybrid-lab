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
  default     = false
}

variable "enable_ssh_access" {
  description = "Allow SSH from 0.0.0.0/0 to instances (for lab only)"
  type        = bool
  default     = true
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
