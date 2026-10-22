#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Evernear Production Build & VPS Setup Script for evernear.erai.vn
# Directory layout (matching clanify.app convention):
#   /opt/evernear.erai.vn/flutter -> Flutter Web build (mobile/build/web)
#   /opt/evernear.erai.vn/landing -> Static Landing files (landing/)
# ==============================================================================

DOMAIN="evernear.erai.vn"
API_URL="https://${DOMAIN}/api/v1"
WEB_URL="https://${DOMAIN}"
OPT_ROOT="/opt/evernear"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> [1/4] Building Flutter Web App for ${DOMAIN}..."
cd "${PROJECT_ROOT}/mobile"
flutter build web --release \
  --dart-define=BASE_URL="${API_URL}" \
  --dart-define=WEB_LANDING_URL="${WEB_URL}"

echo "==> [2/4] Syncing Flutter Web & Static Landing to ${OPT_ROOT}..."
sudo mkdir -p "${OPT_ROOT}/flutter" "${OPT_ROOT}/landing"
sudo rsync -av --delete "${PROJECT_ROOT}/mobile/build/web/" "${OPT_ROOT}/flutter/"
sudo rsync -av --delete "${PROJECT_ROOT}/landing/" "${OPT_ROOT}/landing/"
sudo chown -R www-data:www-data "${OPT_ROOT}" 2>/dev/null || true

echo "==> [3/4] Starting Backend, PostgreSQL & Redis via Docker Compose..."
cd "${PROJECT_ROOT}"
docker compose -f docker-compose.prod.yml up -d --build

echo "==> [4/4] Installing Nginx configuration for ${DOMAIN}..."
if [ -d /etc/nginx/sites-available ]; then
  sudo cp "${PROJECT_ROOT}/nginx/${DOMAIN}.conf" "/etc/nginx/sites-available/${DOMAIN}"
  sudo ln -sf "/etc/nginx/sites-available/${DOMAIN}" "/etc/nginx/sites-enabled/${DOMAIN}"
elif [ -d /etc/nginx/conf.d ]; then
  sudo cp "${PROJECT_ROOT}/nginx/${DOMAIN}.conf" "/etc/nginx/conf.d/${DOMAIN}.conf"
fi

if command -v nginx >/dev/null 2>&1; then
  sudo nginx -t && sudo systemctl reload nginx
  echo "==> Nginx reloaded successfully!"
fi

echo "✅ Deployment for https://${DOMAIN} complete!"
