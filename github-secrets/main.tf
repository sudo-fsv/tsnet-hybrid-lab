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
  plaintext_value   = var.aws_access_key_id
}

resource "github_actions_secret" "aws_secret_key" {
  repository  = var.repository
  secret_name = "AWS_SECRET_ACCESS_KEY"
  plaintext_value   = var.aws_secret_access_key
}

resource "github_actions_secret" "aws_session_token" {
  repository  = var.repository
  secret_name = "AWS_SESSION_TOKEN"
  plaintext_value   = var.aws_session_token
}

resource "github_actions_secret" "tailscale_auth_key" {
  repository  = var.repository
  secret_name = "TAILSCALE_AUTH_KEY"
  plaintext_value   = var.tailscale_auth_key
}

resource "github_actions_secret" "tailscale_oauth_client_id" {
  repository     = var.repository
  secret_name    = "TAILSCALE_OAUTH_CLIENT_ID"
  plaintext_value = var.tailscale_oauth_client_id
}

resource "github_actions_secret" "tailscale_oauth_client_secret" {
  repository     = var.repository
  secret_name    = "TAILSCALE_OAUTH_CLIENT_SECRET"
  plaintext_value = var.tailscale_oauth_client_secret
}
