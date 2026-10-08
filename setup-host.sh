#!/usr/bin/env bash
set -euo pipefail

# Ensure system administration binaries are in PATH
export PATH=$PATH:/usr/sbin:/sbin

if [ "$EUID" -ne 0 ]; then
  echo "Error: setup-host.sh must be run as root."
  exit 1
fi

echo "==> 1. Installing base host packages..."
apt update && apt install -y curl sudo fuse-overlayfs slirp4netns wireguard wireguard-tools gpg

echo "==> 2. Setting up dockuser account and lingering..."
id -u dockuser &>/dev/null || useradd -m -s /bin/bash -G sudo dockuser
echo "dockuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dockuser
usermod --add-subuids 100000-165535 --add-subgids 100000-165535 dockuser
loginctl enable-linger dockuser

echo "==> 3. Setting repository permissions..."
chown -R dockuser:dockuser /opt/vps-stack

echo "==> 4. Installing Nix via Determinate installer..."
if [ ! -d "/nix" ]; then
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
fi

echo "==> 5. Enabling Podman socket for dockuser..."

# 1. Get UID of dockuser
DOCKUSER_UID=$(id -u dockuser)

# 2. Ensure systemd runtime directory exists with correct permissions
mkdir -p "/run/user/${DOCKUSER_UID}"
chown dockuser:dockuser "/run/user/${DOCKUSER_UID}"
chmod 700 "/run/user/${DOCKUSER_UID}"

# 3. Ensure dbus-user-session is installed so user buses can instantiate
apt-get install -y dbus-user-session systemd-container

# 4. Enable and start podman.socket inside a proper PAM user session
machinectl shell dockuser@.host /bin/bash -c "
  export XDG_RUNTIME_DIR=/run/user/${DOCKUSER_UID}
  systemctl --user enable --now podman.socket
"

echo "Host setup complete! Run 'su - dockuser' and execute './bootstrap.sh'."
