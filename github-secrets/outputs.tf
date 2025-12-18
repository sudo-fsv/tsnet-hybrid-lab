output "secrets_written_to_repo" {
  value = [
    github_actions_secret.aws_access_key.secret_name,
    github_actions_secret.aws_secret_key.secret_name,
    github_actions_secret.aws_session_token.secret_name,
    github_actions_secret.tailscale_auth_key.secret_name,
  ]
}