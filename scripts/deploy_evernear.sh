#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Evernear Production Build & VPS Setup Script for evernear.erai.vn
# ==============================================================================

DOMAIN="evernear.erai.vn"
API_URL="https://${DOMAIN}/api/v1"
WEB_URL="https://${DOMAIN}"
WEB_ROOT="/var/www/evernear"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> [1/4] Building Flutter Web App for ${DOMAIN}..."
cd "${PROJECT_ROOT}/mobile"
flutter build web --release \
  --dart-define=BASE_URL="${API_URL}" \
  --dart-define=WEB_LANDING_URL="${WEB_URL}"

echo "==> [2/4] Syncing Static Landing & Flutter Web build to ${WEB_ROOT}..."
sudo mkdir -p "${WEB_ROOT}/landing" "${WEB_ROOT}/web"
sudo rsync -av --delete "${PROJECT_ROOT}/landing/" "${WEB_ROOT}/landing/"
sudo rsync -av --delete "${PROJECT_ROOT}/mobile/build/web/" "${WEB_ROOT}/web/"
sudo chown -R www-data:www-data "${WEB_ROOT}" 2>/dev/null || true

echo "==> [3/4] Starting Backend, PostgreSQL & Redis via Docker Compose..."
cd "${PROJECT_ROOT}"
docker compose -f docker-compose.prod.yml up -d --build

echo "==> [4/4] Installing Nginx site configuration for ${DOMAIN}..."
if [ -d /etc/nginx/sites-available ]; then
  sudo cp "${PROJECT_ROOT}/nginx/${DOMAIN}.conf" "/etc/nginx/sites-available/${DOMAIN}.conf"
  sudo ln -sf "/etc/nginx/sites-available/${DOMAIN}.conf" "/etc/nginx/sites-enabled/${DOMAIN}.conf"
elif [ -d /etc/nginx/conf.d ]; then
  sudo cp "${PROJECT_ROOT}/nginx/${DOMAIN}.conf" "/etc/nginx/conf.d/${DOMAIN}.conf"
fi

if command -v nginx >/dev/null 2>&1; then
  sudo nginx -t && sudo systemctl reload nginx
  echo "==> Nginx reloaded successfully!"
else
  echo "==> Note: nginx binary not found on this machine. Config saved at nginx/${DOMAIN}.conf"
fi

echo "✅ Deployment for https://${DOMAIN} complete!"
