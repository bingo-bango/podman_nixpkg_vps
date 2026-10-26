#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [ "$EUID" -ne 0 ]; then
  echo "Error: must be run as root."
  exit 1
fi

if [ ! -f "${ENV_FILE}" ]; then
  echo "Error: .env not found"
  exit 1
fi

VPS_PRIVATE_KEY=$(grep -E '^VPS_PRIVATE_KEY=' "${ENV_FILE}" | cut -d= -f2- | tr -d '"' | tr -d "'")
HOME_SERVER_PUBLIC_KEY=$(grep -E '^HOME_SERVER_PUBLIC_KEY=' "${ENV_FILE}" | cut -d= -f2- | tr -d '"' | tr -d "'")

if [ -z "${VPS_PRIVATE_KEY}" ] || [ -z "${HOME_SERVER_PUBLIC_KEY}" ]; then
  echo "Error: VPS_PRIVATE_KEY or HOME_SERVER_PUBLIC_KEY missing in .env"
  exit 1
fi

# Ensure tools + module
apt-get update
apt-get install -y wireguard-tools kmod
modprobe wireguard || true
echo wireguard > /etc/modules-load.d/wireguard.conf

mkdir -p /etc/wireguard

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = ${VPS_PRIVATE_KEY}
Address = 10.13.13.1/24
ListenPort = 51456

[Peer]
# Home Server Peer
PublicKey = ${HOME_SERVER_PUBLIC_KEY}
AllowedIPs = 10.13.13.2/32
PersistentKeepalive = 25
EOF

chmod 600 /etc/wireguard/wg0.conf

# IP forwarding
grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1 >/dev/null

# UFW already allows 51456/udp from setup-host.sh; ensure it
ufw allow 51456/udp comment 'WireGuard' || true

systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

echo "Host WireGuard (wg0) is up on 51456/udp"
wg show