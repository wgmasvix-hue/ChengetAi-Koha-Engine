#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.env"
TEMPLATE_FILE="$ROOT/config/nginx/koha.conf.template"
NGINX_CONFIG_FILE="$ROOT/config/nginx/koha.conf"
CERTS_DIR="$ROOT/config/certs"
json_escape() {
    local value="${1:-}"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/}
    printf '%s' "$value"
}

log() {
    local level="$1"
    local message="$2"
    shift 2 || true

    printf '{"ts":"%s","level":"%s","msg":"%s"' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$(json_escape "$level")" \
        "$(json_escape "$message")"

    while [ "$#" -gt 0 ]; do
        local key="${1%%=*}"
        local value="${1#*=}"
        printf ',"%s":"%s"' "$(json_escape "$key")" "$(json_escape "$value")"
        shift
    done

    printf '}\n'
}

info() {
    log INFO "$@"
}

warn() {
    log WARN "$@"
}

die() {
    log ERROR "$1"
    exit 1
}

slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//'
}

sanitize_admin_user() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_'
}

random_string() {
    local size="${1:-24}"
    od -An -N64 -tx1 /dev/urandom | tr -d ' \n' | cut -c1-"$size"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_docker() {
    require_command docker
    docker info >/dev/null 2>&1 || die "Docker daemon is not running"
    docker compose version >/dev/null 2>&1 || die "Docker Compose plugin is required"
}

load_env() {
    [ -f "$ENV_FILE" ] || die "Missing $ENV_FILE. Run configure first."
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a
    export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-chengetai-${DEPLOY_NAME:-koha}}"
}

compose() {
    docker compose \
        --project-directory "$ROOT" \
        --env-file "$ENV_FILE" \
        -p "$COMPOSE_PROJECT_NAME" \
        "$@"
}

ensure_directories() {
    mkdir -p "$ROOT/config/nginx" "$CERTS_DIR"
}

host_display() {
    echo "${KOHA_DOMAIN:-localhost}"
}

opac_url() {
    echo "https://$(host_display):${UI_PORT}"
}

staff_url() {
    echo "https://$(host_display):${STAFF_PORT}"
}

print_access_details() {
    info "Koha deployment ready" \
        "opac_url=$(opac_url)" \
        "staff_url=$(staff_url)" \
        "admin_user=${MYSQL_USER}"
    echo ""
    echo "Administrator credentials"
    echo "  Username : ${MYSQL_USER}"
    echo "  Password : ${MYSQL_PASSWORD}"
    echo ""
    echo "Access URLs"
    echo "  OPAC URL  : $(opac_url)"
    echo "  Staff URL : $(staff_url)"
    echo ""
}

service_container_id() {
    local service="$1"
    compose ps -q "$service"
}

prepare_mariadb_client_file() {
    local ******
    local host_file container

    host_file="$(mktemp)"
    chmod 600 "$host_file"
    cat > "$host_file" <<EOF
[client]
user=root
******
EOF

    container="$(service_container_id mariadb)"
    [ -n "$container" ] || die "MariaDB container is not running"
    docker cp "$host_file" "$container:/tmp/chengetai-client.cnf" >/dev/null
    rm -f "$host_file"
}

cleanup_mariadb_client_file() {
    compose exec -T mariadb rm -f /tmp/chengetai-client.cnf >/dev/null 2>&1 || true
}

service_health_status() {
    local service="$1"
    local container
    container="$(service_container_id "$service")"
    [ -n "$container" ] || return 1

    docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container" 2>/dev/null
}

wait_for_service() {
    local service="$1"
    local attempts="${2:-60}"
    local sleep_seconds="${3:-5}"
    local attempt status

    for attempt in $(seq 1 "$attempts"); do
        status="$(service_health_status "$service" || true)"
        case "$status" in
            healthy|running)
                info "Service ready" "service=$service" "status=$status"
                return 0
                ;;
            unhealthy|exited|dead)
                die "Service $service failed with status $status"
                ;;
        esac
        sleep "$sleep_seconds"
    done

    die "Timed out waiting for service $service"
}

wait_for_url() {
    local label="$1"
    local url="$2"
    local attempts="${3:-30}"
    local sleep_seconds="${4:-5}"
    local curl_opts=()
    local attempt

    if [[ "$url" == https://* ]]; then
        curl_opts+=(--insecure)
    fi

    for attempt in $(seq 1 "$attempts"); do
        if curl -fsS "${curl_opts[@]}" "$url" >/dev/null 2>&1; then
            info "URL ready" "label=$label" "url=$url"
            return 0
        fi
        sleep "$sleep_seconds"
    done

    die "Timed out waiting for $label at $url"
}

check_url() {
    local label="$1"
    local url="$2"
    local curl_opts=()

    if [[ "$url" == https://* ]]; then
        curl_opts+=(--insecure)
    fi

    if curl -fsS "${curl_opts[@]}" "$url" >/dev/null 2>&1; then
        info "URL healthy" "label=$label" "url=$url"
        return 0
    fi

    warn "URL unhealthy" "label=$label" "url=$url"
    return 1
}

is_valid_ip() {
    command -v python3 >/dev/null 2>&1 || return 1
    python3 - "$1" <<'PYTHON' >/dev/null 2>&1
import ipaddress
import sys
ipaddress.ip_address(sys.argv[1])
PYTHON
}

generate_tls_assets() {
    local cert_target key_target san

    [ "${TLS_ENABLED:-true}" = "true" ] || return 0

    cert_target="$ROOT/${TLS_CERT_FILE:-config/certs/tls.crt}"
    key_target="$ROOT/${TLS_KEY_FILE:-config/certs/tls.key}"
    mkdir -p "$(dirname "$cert_target")" "$(dirname "$key_target")"

    if [ -f "$cert_target" ] && [ -f "$key_target" ]; then
        info "Reusing TLS assets" "cert=$cert_target"
        return 0
    fi

    require_command openssl

    san="DNS:localhost,IP:127.0.0.1"
    if is_valid_ip "$KOHA_DOMAIN"; then
        san="$san,IP:${KOHA_DOMAIN}"
    else
        case "$KOHA_DOMAIN" in
            *[!0-9.]*|"" ) ;;
            * )
                if ! command -v python3 >/dev/null 2>&1; then
                    warn "python3 unavailable; treating numeric-looking KOHA_DOMAIN as a DNS SAN" "host=${KOHA_DOMAIN}"
                fi
                ;;
        esac
        if [ "$KOHA_DOMAIN" != "localhost" ]; then
            san="$san,DNS:${KOHA_DOMAIN}"
        fi
    fi

    openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout "$key_target" \
        -out "$cert_target" \
        -days 3650 \
        -subj "/CN=${KOHA_DOMAIN}" \
        -addext "subjectAltName=${san}" >/dev/null 2>&1

    chmod 600 "$key_target"
    chmod 644 "$cert_target"
    info "Generated self-signed TLS assets" "cert=$cert_target"
}

render_nginx_config() {
    local cert_path key_path cert_mount key_mount server_name

    [ -f "$TEMPLATE_FILE" ] || die "Missing Nginx template: $TEMPLATE_FILE"

    cert_path="$ROOT/${TLS_CERT_FILE:-config/certs/tls.crt}"
    key_path="$ROOT/${TLS_KEY_FILE:-config/certs/tls.key}"
    [ -f "$cert_path" ] || die "TLS certificate not found: $cert_path"
    [ -f "$key_path" ] || die "TLS key not found: $key_path"

    cert_mount="/etc/nginx/certs/$(basename "$cert_path")"
    key_mount="/etc/nginx/certs/$(basename "$key_path")"
    server_name="$(host_display)"

    sed \
        -e "s|__OPAC_SERVER_NAME__|$server_name|g" \
        -e "s|__STAFF_SERVER_NAME__|$server_name|g" \
        -e "s|__TLS_CERT__|$cert_mount|g" \
        -e "s|__TLS_KEY__|$key_mount|g" \
        "$TEMPLATE_FILE" > "$NGINX_CONFIG_FILE"

    info "Rendered Nginx configuration" "file=$NGINX_CONFIG_FILE"
}

bundle_prerequisites() {
    ensure_directories
    generate_tls_assets || die "Failed to prepare TLS assets"
    render_nginx_config || die "Failed to render Nginx configuration"
}
