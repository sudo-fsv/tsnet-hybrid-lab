#!/bin/bash
set -e

# Template variables provided by Terraform:
#   ${github_owner}
#   ${github_repo}
#   ${github_runner_token}    # optional pre-provisioned registration token
#   ${github_token}           # optional PAT to request a registration token
#   ${runner_name}
#   ${runner_labels}

OWNER="${github_owner}"
REPO="${github_repo}"
TOKEN="${github_runner_token}"
GITHUB_TOKEN="${github_token}"
NAME="${runner_name}"
LABELS="${runner_labels}"

exec > /var/log/user-data.log 2>&1
echo "Starting runner user-data"

# Update packages and install dependencies
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y jq git curl tar gzip unzip ca-certificates

# Install Node.js 20 (required by some actions); use NodeSource installer
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install --update
rm -rf aws awscliv2.zip

# Install kubectl (stable)
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/$KUBECTL_VERSION/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check - || exit 1
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl kubectl.sha256

WORKDIR="/home/ubuntu/actions-runner"
mkdir -p "$WORKDIR"
chown ubuntu:ubuntu "$WORKDIR"

cd "$WORKDIR"

echo "Fetching latest GitHub Actions runner release URL"
LATEST_URL=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.assets[] | select(.name|test("actions-runner-linux-x64")) | .browser_download_url' | head -n1)
echo "Download URL: $LATEST_URL"
curl -o actions-runner.tar.gz -L "$LATEST_URL"
tar xzf actions-runner.tar.gz
chown -R ubuntu:ubuntu "$WORKDIR"

echo "Configuring runner"

# Validate owner/repo
if [ -z "$OWNER" ] || [ -z "$REPO" ]; then
  echo "Missing required GitHub runner configuration (owner/repo)"
  exit 1
fi

# Obtain registration token if not provided
if [ -z "$TOKEN" ]; then
  if [ -z "$GITHUB_TOKEN" ]; then
    echo "Missing GitHub PAT (github_token) to request a registration token"
    exit 1
  fi

  echo "Requesting registration token from GitHub API"
  API_URL="https://api.github.com/repos/$OWNER/$REPO/actions/runners/registration-token"
  TOKEN_JSON=$(curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" "$API_URL")
  TOKEN=$(echo "$TOKEN_JSON" | jq -r .token)
  if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "Failed to obtain registration token: $TOKEN_JSON"
    exit 1
  fi
fi

sudo -u ubuntu bash -lc "./config.sh --unattended --url https://github.com/$OWNER/$REPO --token $TOKEN --name \"$NAME\" --labels \"$LABELS\""

[ -n "$(command -v systemctl 2>/dev/null)" ] && cat >/etc/systemd/system/github-actions-runner.service <<'SERVICE'
[Unit]
Description=GitHub Actions Runner
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/actions-runner
ExecStart=/home/ubuntu/actions-runner/run.sh
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload || true
systemctl enable --now github-actions-runner || true

echo "Runner setup complete"
