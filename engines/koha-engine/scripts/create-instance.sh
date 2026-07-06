#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/scripts/common.sh"

require_docker
load_env

info "Verifying Koha instance" "instance=$KOHA_INSTANCE"
compose up -d koha >/dev/null
wait_for_service koha 80 5

if compose exec -T koha test -f "/etc/koha/sites/${KOHA_INSTANCE}/koha-conf.xml"; then
    info "Koha instance available" "instance=$KOHA_INSTANCE"
    exit 0
fi

die "Koha instance ${KOHA_INSTANCE} was not created by the container startup logic"
