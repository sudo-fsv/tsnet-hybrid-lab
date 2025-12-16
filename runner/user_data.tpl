#!/bin/bash
set -e

# Template variables provided by Terraform:
#   ${github_owner}
#   ${github_repo}
#   ${github_runner_token}
#   ${runner_name}
#   ${runner_labels}

OWNER="${github_owner}"
REPO="${github_repo}"
TOKEN="${github_runner_token}"
NAME="${runner_name}"
LABELS="${runner_labels}"

exec > /var/log/user-data.log 2>&1
echo "Starting runner user-data"

# Update packages and install dependencies
yum update -y
yum install -y jq git curl tar gzip

WORKDIR="/home/ec2-user/actions-runner"
mkdir -p "$WORKDIR"
chown ec2-user:ec2-user "$WORKDIR"

cd "$WORKDIR"

echo "Fetching latest GitHub Actions runner release URL"
LATEST_URL=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.assets[] | select(.name|test("actions-runner-linux-x64")) | .browser_download_url' | head -n1)
echo "Download URL: $LATEST_URL"
curl -o actions-runner.tar.gz -L "$LATEST_URL"
tar xzf actions-runner.tar.gz
chown -R ec2-user:ec2-user "$WORKDIR"

echo "Configuring runner"
# Ensure token/URL are present; the script will exit if token is empty
if [ -z "$TOKEN" ] || [ -z "$OWNER" ] || [ -z "$REPO" ]; then
  echo "Missing required GitHub runner configuration (owner/repo/token)"
  exit 1
fi

sudo -u ec2-user bash -lc "./config.sh --unattended --url https://github.com/${github_owner}/${github_repo} --token ${github_runner_token} --name \"${runner_name}\" --labels \"${runner_labels}\""

cat >/etc/systemd/system/github-actions-runner.service <<'SERVICE'
[Unit]
Description=GitHub Actions Runner
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/home/ec2-user/actions-runner
ExecStart=/home/ec2-user/actions-runner/run.sh
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now github-actions-runner

echo "Runner setup complete"
