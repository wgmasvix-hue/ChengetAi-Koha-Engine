#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BACKUP_DIR="${1:-}"
[ -n "$BACKUP_DIR" ] || {
    echo "Usage: restore.sh <backup-directory>" >&2
    exit 1
}

DB_DUMP="$BACKUP_DIR/koha-db.sql.gz"
DATA_ARCHIVE="$BACKUP_DIR/koha-data.tar.gz"
[ -f "$DB_DUMP" ] || {
    echo "Database dump not found: $DB_DUMP" >&2
    exit 1
}
[ -f "$DATA_ARCHIVE" ] || {
    echo "Koha data archive not found: $DATA_ARCHIVE" >&2
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

docker compose stop koha || true
docker compose up -d mariadb memcached elasticsearch
docker compose exec -T mariadb mariadb -u root -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS \`$MYSQL_DATABASE\`; CREATE DATABASE \`$MYSQL_DATABASE\`;"
gunzip -c "$DB_DUMP" | docker compose exec -T mariadb mariadb -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"
docker compose run --rm --no-deps koha sh -lc 'rm -rf /var/lib/koha/* && tar xzf - -C /var/lib' < "$DATA_ARCHIVE"
docker compose up -d koha
bash "$ROOT/scripts/healthcheck.sh" --wait

echo "Koha restore completed from $BACKUP_DIR"
