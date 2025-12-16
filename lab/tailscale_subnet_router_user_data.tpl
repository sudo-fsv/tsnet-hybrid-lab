#!/bin/bash
set -e
exec > /var/log/tailscale-subnet-router-user-data.log 2>&1

TAILSCALE_KEY="${tailscale_auth_key}"
ADVERTISE="${advertise_cidrs}"

if [ -z "${TAILSCALE_KEY}" ]; then
  echo "No Tailscale auth key provided; skipping subnet router setup"
  exit 0
fi

apt-get update -y
apt-get install -y curl gnupg
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.gpg | apt-key add -
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.list | tee /etc/apt/sources.list.d/tailscale.list
apt-get update -y
apt-get install -y tailscale

# Bring Tailscale up and advertise routes for the client's private subnets
tailscale up --authkey ${TAILSCALE_KEY} --accept-routes --advertise-routes=${ADVERTISE} || true

echo "Tailscale subnet router started, advertising: ${ADVERTISE}"
