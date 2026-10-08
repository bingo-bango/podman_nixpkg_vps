#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [ "$EUID" -ne 0 ]; then
  echo "Error: must be run as root."
  exit 1
fi

echo "==> Setting up WireGuard configuration..."

if [ ! -f "${ENV_FILE}" ]; then
  echo "Error: .env not found at ${ENV_FILE}"
  exit 1
fi

VPS_PRIVATE_KEY=$(grep -E '^VPS_PRIVATE_KEY=' "${ENV_FILE}" | cut -d= -f2- | tr -d '"' | tr -d "'")
HOME_SERVER_PUBLIC_KEY=$(grep -E '^HOME_SERVER_PUBLIC_KEY=' "${ENV_FILE}" | cut -d= -f2- | tr -d '"' | tr -d "'")

if [ -z "${VPS_PRIVATE_KEY}" ] || [ -z "${HOME_SERVER_PUBLIC_KEY}" ]; then
  echo "Error: VPS_PRIVATE_KEY or HOME_SERVER_PUBLIC_KEY missing in .env"
  exit 1
fi

mkdir -p /etc/wireguard

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = ${VPS_PRIVATE_KEY}
Address = 10.13.13.1/24
ListenPort = 51456

[Peer]
# Home Server Peer
PublicKey = ${HOME_SERVER_PUBLIC_KEY}
# Peer is the home server. Traefik on this VPS should proxy to 10.13.13.2:<port>
AllowedIPs = 10.13.13.2/32
PersistentKeepalive = 25
EOF

chmod 600 /etc/wireguard/wg0.conf

# Enable IPv4 forwarding
grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1 >/dev/null

# Open WireGuard port
if command -v ufw >/dev/null 2>&1; then
  ufw allow 51456/udp comment 'WireGuard'
fi

systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

echo "WireGuard configured and wg0 interface started."
