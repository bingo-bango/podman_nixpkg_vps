# podman_nixpkg_vps
VPS setup for Podman

## Debian Setup
After booting into a freshly installed Debian 12 OS, run the following to install git and clone this repo:
```
apt update && apt install -y git
git clone https://github.com/bingo-bango/podman_nixpkg_vps.git /opt/vps-stack
cd /opt/vps-stack
```

*Verification*: Run `pwd` to confirm you are in `/opt/vps-stack` and `git status` to verify your repository files are present.
