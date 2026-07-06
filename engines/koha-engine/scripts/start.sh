#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[ -f .env ] || {
    echo "Missing $ROOT/.env. Run configure first." >&2
    exit 1
}

echo "====================================="
echo " Starting ChengetAi Koha Engine"
echo "====================================="

docker compose up -d
bash "$ROOT/scripts/healthcheck.sh" --wait
