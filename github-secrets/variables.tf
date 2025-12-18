variable "github_token" {
  description = "A GitHub token with repo:public_repo or repo scope to create repository secrets"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub owner (user or org)"
  type        = string
}

variable "github_repo" {
  description = "Repository name where to store the secrets"
  type        = string
}

variable "aws_access_key_id" {
  description = "AWS access key id (session)"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS secret access key (session)"
  type        = string
  sensitive   = true
}

variable "aws_session_token" {
  description = "AWS session token (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tailscale_auth_key" {
  description = "Tailscale auth key for registering nodes"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tailscale_oauth_client_id" {
  description = "Tailscale OAuth client id for operator/device integration"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tailscale_oauth_client_secret" {
  description = "Tailscale OAuth client secret for operator/device integration"
  type        = string
  sensitive   = true
  default     = ""
}
