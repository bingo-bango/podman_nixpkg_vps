#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# 1. Validate environment file
if [ ! -f .env ]; then
  echo "Error: .env file missing in repository root."
  echo "Please ensure that .env exists and configure your secrets before running."
  exit 1
fi

# 2. Prepare persistent directory permissions
mkdir -p config/traefik config/vaultwarden config/systemd
touch config/traefik/acme.json
chmod 600 config/traefik/acme.json

# 3. Link systemd user units and enable daily automated backups
echo "Configuring automated backup timer..."
mkdir -p ~/.config/systemd/user
ln -sf "${SCRIPT_DIR}/config/systemd/vps-backup.service" ~/.config/systemd/user/
ln -sf "${SCRIPT_DIR}/config/systemd/vps-backup.timer" ~/.config/systemd/user/

systemctl --user daemon-reload
systemctl --user enable --now vps-backup.timer

# 4. Check database state and restore from pCloud if missing
if [ ! -f "./config/vaultwarden/db.sqlite3" ]; then
  echo "Vaultwarden database missing. Restoring latest backup from pCloud..."
  nix run .#restore || echo "Notice: Restore skipped or no backup found."
fi

# 5. Launch stack
echo "Deploying stack via Nix Flake App..."
nix run .#up

echo ""
echo "=========================================================="
echo " Stack deployment complete!"
echo " Check container status: nix develop --command podman ps"
echo " Check backup timer:     systemctl --user status vps-backup.timer"
echo "=========================================================="
