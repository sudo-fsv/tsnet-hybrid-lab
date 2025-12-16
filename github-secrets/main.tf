provider "github" {
  token = var.github_token
  owner = var.github_owner
}

# Repository-level GitHub Actions secrets for AWS session credentials.
# Requires: set var.repository to the target repository name (owner/repo is not required here,
# provider `owner` + `repository` is used by resources below).

resource "github_actions_secret" "aws_access_key" {
  repository  = var.repository
  secret_name = "AWS_ACCESS_KEY_ID"
  plaintext   = var.aws_access_key_id
}

resource "github_actions_secret" "aws_secret_key" {
  repository  = var.repository
  secret_name = "AWS_SECRET_ACCESS_KEY"
  plaintext   = var.aws_secret_access_key
}

resource "github_actions_secret" "aws_session_token" {
  repository  = var.repository
  secret_name = "AWS_SESSION_TOKEN"
  plaintext   = var.aws_session_token
}

output "secrets_written_to_repo" {
  value = [github_actions_secret.aws_access_key.secret_name, github_actions_secret.aws_secret_key.secret_name, github_actions_secret.aws_session_token.secret_name]
}
