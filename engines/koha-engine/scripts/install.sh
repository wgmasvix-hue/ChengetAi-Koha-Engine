#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[ -f .env ] || {
    echo "Missing $ROOT/.env. Run configure first." >&2
    exit 1
}

echo "======================================"
echo " ChengetAi Koha Engine Installer"
echo "======================================"

docker compose pull
docker compose up -d --remove-orphans
bash "$ROOT/scripts/healthcheck.sh" --wait

echo
echo "Koha services started successfully."
