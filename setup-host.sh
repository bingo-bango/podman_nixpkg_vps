#!/usr/bin/env bash
set -euo pipefail

# 1. Fix Debian default root PATH for administrative tools
export PATH=$PATH:/usr/sbin:/sbin

if [ "$EUID" -ne 0 ]; then
  echo "Error: setup-host.sh must be run as root."
  exit 1
fi

echo "==> 1. Updating APT packages & installing host prerequisites..."
apt update && apt install -y \
  curl \
  git \
  sudo \
  podman \
  dbus-user-session \
  systemd-container \
  slirp4netns \
  fuse-overlayfs

echo "==> 2. Setting up 'dockuser' account and lingering..."
if ! id -u dockuser &>/dev/null; then
  useradd -m -s /bin/bash -G sudo dockuser
  echo "dockuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dockuser
fi

# Assign subordinate UIDs/GIDs for rootless Podman container namespaces
usermod --add-subuids 100000-165535 --add-subgids 100000-165535 dockuser || true

# Keep user-level systemd daemons alive on boot without an active SSH session
loginctl enable-linger dockuser

echo "==> 3. Installing Nix via Determinate Installer..."
if [ ! -d "/nix" ]; then
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
fi

echo "==> 4. Initializing user systemd runtime & starting Podman socket..."
DOCKUSER_UID=$(id -u dockuser)

# Ensure the user manager is running
systemctl start "user@${DOCKUSER_UID}.service" || true

# Enable and start the socket (exit code is correctly propagated)
systemctl --user --machine="dockuser@" enable --now podman.socket

# Run systemctl inside dockuser's systemd user session context
machinectl shell dockuser@.host /bin/bash -c "
  export XDG_RUNTIME_DIR=/run/user/${DOCKUSER_UID}
  systemctl --user enable --now podman.socket
"

echo ""
echo "=========================================================="
echo " Host setup successful!"
echo "=========================================================="
echo "To complete deployment, run:"
echo "  1. su - dockuser"
echo "  2. cd /path/to/your/repo"
echo "  3. nix run .#up"
echo "=========================================================="
