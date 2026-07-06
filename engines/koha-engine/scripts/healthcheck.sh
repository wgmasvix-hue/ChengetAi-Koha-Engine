#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/scripts/common.sh"

WAIT=0
if [ "${1:-}" = "--wait" ]; then
    WAIT=1
fi

require_command curl
require_docker
load_env

services=(mariadb memcached opensearch rabbitmq koha nginx)
failed=0
for service in "${services[@]}"; do
    if [ "$WAIT" -eq 1 ]; then
        wait_for_service "$service" 80 3
    else
        status="$(service_health_status "$service" || true)"
        if [ -z "$status" ]; then
            warn "Service not found" "service=$service"
            failed=1
        elif [ "$status" = "healthy" ] || [ "$status" = "running" ]; then
            info "Service healthy" "service=$service" "status=$status"
        else
            warn "Service unhealthy" "service=$service" "status=$status"
            failed=1
        fi
    fi
done

if [ "$WAIT" -eq 1 ]; then
    wait_for_url "OPAC" "$(opac_url)" 40 3
    wait_for_url "Staff" "$(staff_url)" 40 3
else
    check_url "OPAC" "$(opac_url)" || failed=1
    check_url "Staff" "$(staff_url)" || failed=1
    [ "$failed" -eq 0 ] || exit 1
fi
