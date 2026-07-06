#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.env"

if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a
fi

random_string() {
    od -An -N24 -tx1 /dev/urandom | tr -d ' \n' | cut -c1-32
}

slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//'
}

DEPLOY_NAME="${DEPLOY_NAME:-koha}"
INSTANCE_SLUG="$(slugify "${REPOSITORY:-$DEPLOY_NAME}")"
INSTANCE_SLUG="${INSTANCE_SLUG:-koha}"
ADMIN_USER_DEFAULT="$(echo "${KOHA_ADMINUSER:-${ADMIN_EMAIL%%@*}}" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')"
ADMIN_USER_DEFAULT="${ADMIN_USER_DEFAULT:-admin}"

UI_PORT="${UI_PORT:-${KOHA_OPAC_PORT:-4000}}"
REST_PORT="${REST_PORT:-${KOHA_INTRANET_PORT:-8080}}"
TZ="${TZ:-UTC}"
KOHA_DOMAIN="${KOHA_DOMAIN:-localhost}"
KOHA_INSTANCE="${KOHA_INSTANCE:-$INSTANCE_SLUG}"
KOHA_ADMINUSER="${KOHA_ADMINUSER:-$ADMIN_USER_DEFAULT}"
KOHA_ADMINPASS="${ADMIN_PASS:-${KOHA_ADMINPASS:-}}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-$(random_string)}"
MYSQL_DATABASE="${MYSQL_DATABASE:-koha_${INSTANCE_SLUG//-/_}}"
MYSQL_USER="${MYSQL_USER:-koha}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-$(random_string)}"

[ -n "$KOHA_ADMINPASS" ] || {
    echo "ADMIN_PASS or KOHA_ADMINPASS is required to configure the Koha engine." >&2
    exit 1
}

cat > "$ENV_FILE" <<EOT
DEPLOY_NAME=${DEPLOY_NAME}
INSTITUTION=${INSTITUTION:-$DEPLOY_NAME}
REPOSITORY=${REPOSITORY:-$DEPLOY_NAME}
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@example.com}
ADMIN_FIRST_NAME=${ADMIN_FIRST_NAME:-Koha}
ADMIN_LAST_NAME=${ADMIN_LAST_NAME:-Administrator}
TZ=${TZ}
UI_PORT=${UI_PORT}
REST_PORT=${REST_PORT}
KOHA_DOMAIN=${KOHA_DOMAIN}
KOHA_INSTANCE=${KOHA_INSTANCE}
KOHA_ADMINUSER=${KOHA_ADMINUSER}
KOHA_ADMINPASS=${KOHA_ADMINPASS}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_DATABASE=${MYSQL_DATABASE}
MYSQL_USER=${MYSQL_USER}
MYSQL_PASSWORD=${MYSQL_PASSWORD}
EOT

chmod 600 "$ENV_FILE"
echo "Koha engine configured: $ENV_FILE"
