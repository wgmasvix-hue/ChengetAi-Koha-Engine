#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/scripts/common.sh"

require_docker
load_env
bundle_prerequisites

info "Pulling required images"
compose pull

info "Starting infrastructure services"
compose up -d mariadb memcached opensearch rabbitmq
wait_for_service mariadb 40 5
wait_for_service memcached 20 3
wait_for_service opensearch 60 5
wait_for_service rabbitmq 40 5

info "Starting Koha service"
compose up -d koha
wait_for_service koha 80 5

bash "$ROOT/scripts/create-instance.sh"

info "Starting HTTPS reverse proxy"
compose up -d nginx
wait_for_service nginx 40 3

bash "$ROOT/scripts/healthcheck.sh" --wait
print_access_details
