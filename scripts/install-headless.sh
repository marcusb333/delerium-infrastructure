#!/usr/bin/env bash
set -euo pipefail

# Refuse running as root; use sudo for privileged steps instead
if [ "${EUID:-$(id -u)}" -eq 0 ]; then
  echo "[delirium] Do not run this script as root. Re-run without sudo; the script will use sudo where needed."
  exit 1
fi

# Delirium - Headless Ubuntu VPS install script
# Usage (default /opt/delirium):
#   curl -fsSL https://raw.githubusercontent.com/your-username/delerium-paste/main/scripts/install-headless.sh | bash
# Custom dir via env:
#   APP_DIR=/srv/delirium curl -fsSL https://raw.githubusercontent.com/your-username/delerium-paste/main/scripts/install-headless.sh | bash
# Custom dir via arg (with -s -- to pass args to bash):
#   curl -fsSL https://raw.githubusercontent.com/your-username/delerium-paste/main/scripts/install-headless.sh | bash -s -- /srv/delirium
# Or copy this file to the server and run: bash install-headless.sh [/custom/path]

REPO_URL="https://github.com/your-username/delerium-paste.git"
TAG="v0.1.6-alpha"
# Install directory (env APP_DIR or first arg, defaults to /opt/delirium)
APP_DIR="${APP_DIR:-${1:-/opt/delirium}}"

log() { echo -e "[delirium] $*"; }

log "[1/6] Installing prerequisites (curl, git, ufw, unzip)…"
sudo apt update -y
sudo apt install -y curl git ufw unzip ca-certificates

log "[2/6] Installing Docker if missing…"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
fi

log "[3/6] SSH-safe firewall setup…"
sudo ufw allow OpenSSH || true    # port 22
sudo ufw allow 80/tcp || true
sudo ufw allow 443/tcp || true
echo y | sudo ufw enable >/dev/null 2>&1 || true
sudo ufw status verbose || true

log "[4/6] Fetching app into ${APP_DIR}…"
sudo mkdir -p "$APP_DIR"
sudo chown "$USER":"$USER" "$APP_DIR"
cd "$APP_DIR"

if command -v git >/dev/null 2>&1; then
  if [ -d .git ]; then
    git fetch --all --tags
    git checkout "$TAG"
    git pull --ff-only || true
  else
    git clone "$REPO_URL" .
    git checkout "$TAG"
  fi
else
  ZIP_URL="https://github.com/your-username/delerium-paste/archive/refs/tags/${TAG}.zip"
  TMP_ZIP="/tmp/delerium-${TAG}.zip"
  curl -fsSL "$ZIP_URL" -o "$TMP_ZIP"
  unzip -q -o "$TMP_ZIP"
  SRC_DIR="delerium-${TAG#v}"
  if [ -d "$SRC_DIR" ]; then
    cp -a "$SRC_DIR"/. ./
    rm -rf "$SRC_DIR"
  fi
  rm -f "$TMP_ZIP"
fi

log "[5/6] Creating .env (if missing)…"
if [ ! -f .env ]; then
  echo "DELETION_TOKEN_PEPPER=$(openssl rand -hex 32)" > .env
fi

log "[6/6] Starting containers…"
sudo docker compose -f docker-compose.prod.yml up -d

log "Waiting for services…"
sleep 5
sudo docker compose -f docker-compose.prod.yml ps || true
echo "HTTP check:"; curl -s -I http://localhost/ | head -n1 || true
echo "API check:";  curl -s -o /dev/null -w "%{http_code}\n" http://localhost/api/pow || true

cat <<'EOS'

Delirium is up on port 80.

Next steps:
- For SSL: place certs in ./ssl (fullchain.pem, privkey.pem) and update nginx conf if needed, then:
    sudo docker compose -f docker-compose.prod.yml up -d
- Check logs:
    sudo docker compose -f docker-compose.prod.yml logs -f
- Stop services:
    sudo docker compose -f docker-compose.prod.yml down

Security tips:
- This script enabled UFW for ports 22, 80, 443. If SSH uses a custom port, allow it before enabling UFW.
- Rotate DELETION_TOKEN_PEPPER for production secrets management.
EOS


