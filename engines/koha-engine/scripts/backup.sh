#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/scripts/common.sh"

DEST="${1:-}"
[ -n "$DEST" ] || die "Usage: backup.sh <destination-directory>"

require_docker
load_env
mkdir -p "$DEST"

info "Backing up MariaDB"
compose exec -T mariadb mariadb-dump -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" | gzip > "$DEST/koha-db.sql.gz"

info "Archiving Koha state"
compose exec -T koha tar czf - /etc/koha /var/lib/koha /var/log/koha > "$DEST/koha-files.tar.gz"

info "Archiving engine configuration"
tar czf "$DEST/engine-config.tar.gz" -C "$ROOT" .env config

cat > "$DEST/manifest.txt" <<MANIFEST
created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
deploy_name=${DEPLOY_NAME}
koha_instance=${KOHA_INSTANCE}
opac_url=$(opac_url)
staff_url=$(staff_url)
MANIFEST

info "Backup complete" "destination=$DEST"
