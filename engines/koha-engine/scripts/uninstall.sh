#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/scripts/common.sh"

PURGE="${1:-}"

require_docker
load_env

if [ "$PURGE" = "--purge" ] || [ "$PURGE" = "1" ]; then
    info "Removing Koha stack and persistent volumes"
    compose down --remove-orphans --volumes
else
    info "Removing Koha stack but preserving persistent volumes"
    compose down --remove-orphans
fi

info "Koha stack removed"
