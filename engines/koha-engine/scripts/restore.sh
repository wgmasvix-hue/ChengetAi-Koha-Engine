#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/scripts/common.sh"

BACKUP_DIR="${1:-}"
[ -n "$BACKUP_DIR" ] || die "Usage: restore.sh <backup-directory>"

DB_DUMP="$BACKUP_DIR/koha-db.sql.gz"
FILES_ARCHIVE="$BACKUP_DIR/koha-files.tar.gz"
ENGINE_ARCHIVE="$BACKUP_DIR/engine-config.tar.gz"

[ -f "$DB_DUMP" ] || die "Database dump not found: $DB_DUMP"
[ -f "$FILES_ARCHIVE" ] || die "Koha files archive not found: $FILES_ARCHIVE"
[ -f "$ENGINE_ARCHIVE" ] || die "Engine config archive not found: $ENGINE_ARCHIVE"

require_docker
if [ -f "$ENV_FILE" ]; then
    load_env
fi

tar xzf "$ENGINE_ARCHIVE" -C "$ROOT"
load_env
bundle_prerequisites

info "Validating backup archives"
gzip -t "$DB_DUMP"
tar tzf "$FILES_ARCHIVE" >/dev/null

info "Starting required services for restore"
compose up -d mariadb memcached opensearch rabbitmq
wait_for_service mariadb 40 5
wait_for_service memcached 20 3
wait_for_service opensearch 60 5
wait_for_service rabbitmq 40 5

info "Stopping application services during restore"
compose stop nginx koha || true

info "Restoring MariaDB"
compose exec -T -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mariadb mariadb -u root -e "DROP DATABASE IF EXISTS \`$MYSQL_DATABASE\`; CREATE DATABASE \`$MYSQL_DATABASE\`;"
gunzip -c "$DB_DUMP" | compose exec -T -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mariadb mariadb -u root "$MYSQL_DATABASE"

info "Restoring Koha files"
compose run --rm --no-deps -T koha sh <<'EOSH'
set -e
rm -rf /etc/koha/sites/*
rm -rf /var/lib/koha/*
rm -rf /var/log/koha/*
mkdir -p /etc/koha/sites /var/lib/koha /var/log/koha
test -w /etc/koha/sites
test -w /var/lib/koha
test -w /var/log/koha
EOSH
cat "$FILES_ARCHIVE" | compose run --rm --no-deps -T koha tar xzf - -C /

info "Restarting full stack"
compose up -d --remove-orphans
bash "$ROOT/scripts/healthcheck.sh" --wait
print_access_details
