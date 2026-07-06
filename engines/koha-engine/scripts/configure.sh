#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/scripts/common.sh"

if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a
fi

DEPLOY_NAME="${DEPLOY_NAME:-koha}"
INSTANCE_SLUG="$(slugify "${REPOSITORY:-$DEPLOY_NAME}")"
INSTANCE_SLUG="${INSTANCE_SLUG:-koha}"
ADMIN_USER_DEFAULT="$(printf '%s' "${KOHA_ADMINUSER:-${ADMIN_EMAIL%%@*}}" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_')"
ADMIN_USER_DEFAULT="${ADMIN_USER_DEFAULT:-admin}"

UI_PORT="${UI_PORT:-${KOHA_OPAC_PORT:-4000}}"
REST_PORT="${REST_PORT:-${STAFF_PORT:-8080}}"
STAFF_PORT="${STAFF_PORT:-$REST_PORT}"
TZ="${TZ:-UTC}"
KOHA_DOMAIN="${KOHA_DOMAIN:-${SERVER_IP:-localhost}}"
KOHA_INSTANCE="${KOHA_INSTANCE:-$INSTANCE_SLUG}"
KOHA_ADMINUSER="${KOHA_ADMINUSER:-$ADMIN_USER_DEFAULT}"
KOHA_ADMINPASS="${ADMIN_PASS:-${KOHA_ADMINPASS:-$(random_string 24)}}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-$(random_string 32)}"
MYSQL_DATABASE="${MYSQL_DATABASE:-koha_${INSTANCE_SLUG//-/_}}"
MYSQL_USER="${MYSQL_USER:-$KOHA_ADMINUSER}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-${KOHA_ADMINPASS}}"
RABBITMQ_USER="${RABBITMQ_USER:-koha}"
RABBITMQ_PASSWORD="${RABBITMQ_PASSWORD:-$(random_string 32)}"
RABBITMQ_STOMP_PORT="${RABBITMQ_STOMP_PORT:-61613}"
MEMCACHED_SERVERS="${MEMCACHED_SERVERS:-memcached:11211}"
ELASTICSEARCH_HOST="${ELASTICSEARCH_HOST:-opensearch}"
OPENSEARCH_JAVA_OPTS="${OPENSEARCH_JAVA_OPTS:--Xms512m -Xmx512m}"
KOHA_LANGS="${KOHA_LANGS:-en}"
TLS_ENABLED="${TLS_ENABLED:-true}"
TLS_CERT_FILE="${TLS_CERT_FILE:-config/certs/tls.crt}"
TLS_KEY_FILE="${TLS_KEY_FILE:-config/certs/tls.key}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-chengetai-${DEPLOY_NAME}}"

{
    printf 'DEPLOY_NAME=%q\n' "$DEPLOY_NAME"
    printf 'INSTITUTION=%q\n' "${INSTITUTION:-$DEPLOY_NAME}"
    printf 'REPOSITORY=%q\n' "${REPOSITORY:-$DEPLOY_NAME}"
    printf 'ADMIN_EMAIL=%q\n' "${ADMIN_EMAIL:-admin@example.com}"
    printf 'ADMIN_FIRST_NAME=%q\n' "${ADMIN_FIRST_NAME:-Koha}"
    printf 'ADMIN_LAST_NAME=%q\n' "${ADMIN_LAST_NAME:-Administrator}"
    printf 'TZ=%q\n' "$TZ"
    printf 'UI_PORT=%q\n' "$UI_PORT"
    printf 'REST_PORT=%q\n' "$REST_PORT"
    printf 'STAFF_PORT=%q\n' "$STAFF_PORT"
    printf 'KOHA_DOMAIN=%q\n' "$KOHA_DOMAIN"
    printf 'KOHA_INSTANCE=%q\n' "$KOHA_INSTANCE"
    printf 'KOHA_ADMINUSER=%q\n' "$KOHA_ADMINUSER"
    printf 'KOHA_ADMINPASS=%q\n' "$KOHA_ADMINPASS"
    printf 'MYSQL_ROOT_PASSWORD=%q\n' "$MYSQL_ROOT_PASSWORD"
    printf 'MYSQL_DATABASE=%q\n' "$MYSQL_DATABASE"
    printf 'MYSQL_USER=%q\n' "$MYSQL_USER"
    printf 'MYSQL_PASSWORD=%q\n' "$MYSQL_PASSWORD"
    printf 'RABBITMQ_USER=%q\n' "$RABBITMQ_USER"
    printf 'RABBITMQ_PASSWORD=%q\n' "$RABBITMQ_PASSWORD"
    printf 'RABBITMQ_STOMP_PORT=%q\n' "$RABBITMQ_STOMP_PORT"
    printf 'MEMCACHED_SERVERS=%q\n' "$MEMCACHED_SERVERS"
    printf 'ELASTICSEARCH_HOST=%q\n' "$ELASTICSEARCH_HOST"
    printf 'OPENSEARCH_JAVA_OPTS=%q\n' "$OPENSEARCH_JAVA_OPTS"
    printf 'KOHA_LANGS=%q\n' "$KOHA_LANGS"
    printf 'TLS_ENABLED=%q\n' "$TLS_ENABLED"
    printf 'TLS_CERT_FILE=%q\n' "$TLS_CERT_FILE"
    printf 'TLS_KEY_FILE=%q\n' "$TLS_KEY_FILE"
    printf 'COMPOSE_PROJECT_NAME=%q\n' "$COMPOSE_PROJECT_NAME"
} > "$ENV_FILE"

chmod 600 "$ENV_FILE"
load_env
bundle_prerequisites
info "Koha engine configured" "env_file=$ENV_FILE" "instance=$KOHA_INSTANCE"
