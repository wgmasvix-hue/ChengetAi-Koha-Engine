#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/scripts/common.sh"

require_docker
load_env
bundle_prerequisites

info "Starting Koha stack"
compose up -d
bash "$ROOT/scripts/healthcheck.sh" --wait
print_access_details
