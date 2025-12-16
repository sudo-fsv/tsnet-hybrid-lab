variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-west-2"
}

variable "key_name" {
  description = "Optional EC2 key pair name (leave empty to skip)"
  type        = string
  default     = ""
}

variable "github_owner" {
  description = "GitHub owner (user or org) for the repository the runner will join"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (owner/repo uses provider; here just repo)"
  type        = string
}

variable "github_runner_token" {
  description = "Registration token for the GitHub Actions runner (sensitive)"
  type        = string
  sensitive   = true
}

variable "runner_name" {
  description = "Optional runner name (defaults to instance id)"
  type        = string
  default     = ""
}

variable "runner_labels" {
  description = "List of labels to give the runner"
  type        = list(string)
  default     = []
}
