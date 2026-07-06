#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DEST="${1:-}"
[ -n "$DEST" ] || {
    echo "Usage: backup.sh <destination-directory>" >&2
    exit 1
}

[ -f .env ] || {
    echo "Missing $ROOT/.env. Run configure first." >&2
    exit 1
}

set -a
# shellcheck source=/dev/null
source .env
set +a

mkdir -p "$DEST"

docker compose ps mariadb >/dev/null
docker compose exec -T mariadb mariadb-dump -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" | gzip > "$DEST/koha-db.sql.gz"
docker compose exec -T koha tar czf - -C /var/lib koha > "$DEST/koha-data.tar.gz"

echo "Koha backup written to $DEST"
