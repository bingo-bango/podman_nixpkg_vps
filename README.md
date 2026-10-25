# podman_nixpkg_vps
VPS setup for Podman

## 1. Repo Setup
After booting into a freshly installed Debian 12 OS, run the following as root to install git and clone this repo:
```
apt update && apt install -y git
git clone https://github.com/bingo-bango/podman_nixpkg_vps.git /opt/vps-stack
cd /opt/vps-stack
```

*Verification*: Run `pwd` to confirm you are in `/opt/vps-stack` and `git status` to verify your repository files are present.

## 2. Secrets and access
 - Update the .env file in your repository root (/opt/vps-stack/.env) with the correct values.
 - Put your SSH public key in `~/.ssh/authorized_keys` - *important* so you don't get locked out during the next steps.
 - Update the `VPS_PRIVATE_KEY` and `HOME_SERVER_PUBLIC_KEY` values in config/wireguard/wg_confs/wg0.conf with their correct values.

## 3. System setup
Run:
```
bash setup-host.sh
```
Then switch to `dockuser` and run the boot strap:
```
machinectl shell dockuser@
bash bootstrap.sh
```
