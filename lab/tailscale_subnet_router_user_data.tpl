#!/bin/bash
set -e
# exec > /var/log/tailscale-subnet-router-user-data.log 2>&1

TAILSCALE_KEY="${tailscale_auth_key}"
POD_CIDR="${pod_cidr}"

if [ -z "$POD_CIDR" ]; then
  echo "If a pod CIDR was provided, include it in the advertised routes"
  exit 0
fi

if [ -z "$TAILSCALE_KEY" ]; then
  echo "No Tailscale auth key provided; skipping subnet router setup"
  exit 0
fi

apt-get update -y
apt-get install -y curl gnupg
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.gpg | apt-key add -
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.list | tee /etc/apt/sources.list.d/tailscale.list
apt-get update -y
apt-get install -y tailscale
apt-get install -y iperf3

# Install and enable OpenSSH server so the router is reachable via SSH over Tailscale
apt-get install -y openssh-server
systemctl enable --now ssh || true

# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p /etc/sysctl.conf

# Bring Tailscale up, enable SSH access over Tailscale, and advertise routes
tailscale up --authkey $TAILSCALE_KEY --accept-routes --advertise-routes=$POD_CIDR --ssh || true

echo "Tailscale subnet router started, advertising: $POD_CIDR"