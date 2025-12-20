#!/bin/bash
set -e
# exec > /var/log/tailscale-client-user-data.log 2>&1

TAILSCALE_KEY="${tailscale_auth_key}"
if [ -z "$TAILSCALE_KEY" ]; then
  echo "No Tailscale auth key provided; skipping setup"
  exit 0
fi

apt-get update -y
apt-get install -y curl gnupg
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.gpg | apt-key add -
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.list | tee /etc/apt/sources.list.d/tailscale.list
apt-get update -y
apt-get install -y tailscale
apt-get install -y iperf3


# Bring up tailscale and enable Tailscale SSH on this node.
# Note: Tailscale SSH must also be enabled in your Tailscale admin settings for the
# machine to accept SSH connections via the tailscale network.
tailscale up --authkey "$TAILSCALE_KEY" --hostname "aws-linux-vm" --accept-routes --ssh || true

echo "Tailscale setup finished"
